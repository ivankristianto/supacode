import CoreServices
import Dispatch
import Foundation
import Darwin

@MainActor
final class WorktreeInfoWatcherManager {
  private struct HeadWatcher {
    let headURL: URL
    let source: DispatchSourceFileSystemObject
  }

  private struct TreeWatcher {
    let stream: FSEventStreamRef
    let context: Unmanaged<WorktreeInfoWatcherContext>
  }

  private enum RefreshTiming {
    static let focused = Duration.seconds(30)
    static let unfocused = Duration.seconds(300)
  }

  private var worktrees: [Worktree.ID: Worktree] = [:]
  private var headWatchers: [Worktree.ID: HeadWatcher] = [:]
  private var treeWatchers: [Worktree.ID: TreeWatcher] = [:]
  private var branchDebounceTasks: [Worktree.ID: Task<Void, Never>] = [:]
  private var filesDebounceTasks: [Worktree.ID: Task<Void, Never>] = [:]
  private var restartTasks: [Worktree.ID: Task<Void, Never>] = [:]
  private var pullRequestTasks: [Worktree.ID: Task<Void, Never>] = [:]
  private var selectedWorktreeID: Worktree.ID?
  private var eventContinuation: AsyncStream<WorktreeInfoWatcherClient.Event>.Continuation?

  func handleCommand(_ command: WorktreeInfoWatcherClient.Command) {
    switch command {
    case .setWorktrees(let worktrees):
      setWorktrees(worktrees)
    case .setSelectedWorktreeID(let worktreeID):
      setSelectedWorktreeID(worktreeID)
    case .stop:
      stopAll()
    }
  }

  func eventStream() -> AsyncStream<WorktreeInfoWatcherClient.Event> {
    eventContinuation?.finish()
    let (stream, continuation) = AsyncStream.makeStream(of: WorktreeInfoWatcherClient.Event.self)
    eventContinuation = continuation
    return stream
  }

  private func setWorktrees(_ worktrees: [Worktree]) {
    let worktreesByID = Dictionary(uniqueKeysWithValues: worktrees.map { ($0.id, $0) })
    let desiredIDs = Set(worktreesByID.keys)
    let currentIDs = Set(self.worktrees.keys)
    let removedIDs = currentIDs.subtracting(desiredIDs)
    for id in removedIDs {
      stopWatcher(for: id)
    }
    self.worktrees = worktreesByID
    for worktree in worktrees {
      configureWatcher(for: worktree)
      startTreeWatcher(for: worktree)
      scheduleFilesChanged(worktreeID: worktree.id)
    }
    refreshPullRequestSchedules()
  }

  private func setSelectedWorktreeID(_ worktreeID: Worktree.ID?) {
    guard selectedWorktreeID != worktreeID else {
      return
    }
    selectedWorktreeID = worktreeID
    refreshPullRequestSchedules()
  }

  private func configureWatcher(for worktree: Worktree) {
    guard let headURL = GitWorktreeHeadResolver.headURL(
      for: worktree.workingDirectory,
      fileManager: .default
    ) else {
      stopWatcher(for: worktree.id)
      return
    }
    if let existing = headWatchers[worktree.id], existing.headURL == headURL {
      return
    }
    stopWatcher(for: worktree.id)
    startWatcher(worktreeID: worktree.id, headURL: headURL)
  }

  private func startTreeWatcher(for worktree: Worktree) {
    guard treeWatchers[worktree.id] == nil else {
      return
    }
    let path = worktree.workingDirectory.path(percentEncoded: false)
    guard FileManager.default.fileExists(atPath: path) else {
      return
    }
    let context = WorktreeInfoWatcherContext(manager: self, worktreeID: worktree.id)
    let retainedContext = Unmanaged.passRetained(context)
    var streamContext = FSEventStreamContext(
      version: 0,
      info: retainedContext.toOpaque(),
      retain: nil,
      release: nil,
      copyDescription: nil
    )
    let paths = [path] as CFArray
    let flags = FSEventStreamCreateFlags(
      kFSEventStreamCreateFlagNoDefer
        | kFSEventStreamCreateFlagFileEvents
        | kFSEventStreamCreateFlagWatchRoot
    )
    let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
      guard let clientCallBackInfo else {
        return
      }
      let context = Unmanaged<WorktreeInfoWatcherContext>
        .fromOpaque(clientCallBackInfo)
        .takeUnretainedValue()
      Task { @MainActor in
        context.manager?.handleTreeChange(worktreeID: context.worktreeID)
      }
    }
    guard let stream = FSEventStreamCreate(
      kCFAllocatorDefault,
      callback,
      &streamContext,
      paths,
      FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
      0.2,
      flags
    ) else {
      retainedContext.release()
      return
    }
    let queue = DispatchQueue(label: "worktree-info-watcher.fs.\(worktree.id)")
    FSEventStreamSetDispatchQueue(stream, queue)
    guard FSEventStreamStart(stream) else {
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
      retainedContext.release()
      return
    }
    treeWatchers[worktree.id] = TreeWatcher(stream: stream, context: retainedContext)
  }

  private func startWatcher(worktreeID: Worktree.ID, headURL: URL) {
    let path = headURL.path(percentEncoded: false)
    let fileDescriptor = open(path, O_EVTONLY)
    guard fileDescriptor >= 0 else {
      return
    }
    let queue = DispatchQueue(label: "worktree-info-watcher.\(worktreeID)")
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: [.write, .rename, .delete, .attrib],
      queue: queue
    )
    source.setEventHandler { [weak self, weak source] in
      guard let source else { return }
      let event = source.data
      Task { @MainActor in
        self?.handleEvent(worktreeID: worktreeID, event: event)
      }
    }
    source.setCancelHandler {
      close(fileDescriptor)
    }
    source.resume()
    headWatchers[worktreeID] = HeadWatcher(headURL: headURL, source: source)
  }

  private func handleEvent(
    worktreeID: Worktree.ID,
    event: DispatchSource.FileSystemEvent
  ) {
    if event.contains(.delete) || event.contains(.rename) {
      stopWatcher(for: worktreeID)
      scheduleRestart(worktreeID: worktreeID)
      return
    }
    scheduleBranchChanged(worktreeID: worktreeID)
  }

  private func scheduleBranchChanged(worktreeID: Worktree.ID) {
    branchDebounceTasks[worktreeID]?.cancel()
    let task = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(200))
      await MainActor.run {
        self?.emit(.branchChanged(worktreeID: worktreeID))
      }
    }
    branchDebounceTasks[worktreeID] = task
  }

  private func scheduleFilesChanged(worktreeID: Worktree.ID) {
    filesDebounceTasks[worktreeID]?.cancel()
    let task = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      await MainActor.run {
        self?.emit(.filesChanged(worktreeID: worktreeID))
      }
    }
    filesDebounceTasks[worktreeID] = task
  }

  private func refreshPullRequestSchedules() {
    for task in pullRequestTasks.values {
      task.cancel()
    }
    pullRequestTasks.removeAll()
    for worktreeID in worktrees.keys {
      startPullRequestRefresh(worktreeID: worktreeID)
    }
  }

  private func startPullRequestRefresh(worktreeID: Worktree.ID) {
    let interval = worktreeID == selectedWorktreeID ? RefreshTiming.focused : RefreshTiming.unfocused
    let task = Task { [weak self] in
      await MainActor.run {
        self?.emit(.pullRequestRefresh(worktreeID: worktreeID))
      }
      while !Task.isCancelled {
        try? await Task.sleep(for: interval)
        await MainActor.run {
          self?.emit(.pullRequestRefresh(worktreeID: worktreeID))
        }
      }
    }
    pullRequestTasks[worktreeID] = task
  }

  private func scheduleRestart(worktreeID: Worktree.ID) {
    restartTasks[worktreeID]?.cancel()
    let task = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(200))
      await MainActor.run {
        self?.restartWatcher(worktreeID: worktreeID)
      }
    }
    restartTasks[worktreeID] = task
  }

  fileprivate func handleTreeChange(worktreeID: Worktree.ID) {
    guard let worktree = worktrees[worktreeID] else {
      stopWatcher(for: worktreeID)
      return
    }
    let path = worktree.workingDirectory.path(percentEncoded: false)
    guard FileManager.default.fileExists(atPath: path) else {
      stopWatcher(for: worktreeID)
      return
    }
    scheduleFilesChanged(worktreeID: worktreeID)
  }

  private func restartWatcher(worktreeID: Worktree.ID) {
    guard headWatchers[worktreeID] == nil else {
      return
    }
    guard let worktree = worktrees[worktreeID] else {
      return
    }
    configureWatcher(for: worktree)
  }

  private func stopTreeWatcher(_ watcher: TreeWatcher) {
    FSEventStreamStop(watcher.stream)
    FSEventStreamInvalidate(watcher.stream)
    FSEventStreamRelease(watcher.stream)
    watcher.context.release()
  }

  private func stopWatcher(for worktreeID: Worktree.ID) {
    if let watcher = headWatchers.removeValue(forKey: worktreeID) {
      watcher.source.cancel()
    }
    if let watcher = treeWatchers.removeValue(forKey: worktreeID) {
      stopTreeWatcher(watcher)
    }
    branchDebounceTasks.removeValue(forKey: worktreeID)?.cancel()
    filesDebounceTasks.removeValue(forKey: worktreeID)?.cancel()
    restartTasks.removeValue(forKey: worktreeID)?.cancel()
    pullRequestTasks.removeValue(forKey: worktreeID)?.cancel()
  }

  private func stopAll() {
    for (id, watcher) in headWatchers {
      watcher.source.cancel()
      branchDebounceTasks.removeValue(forKey: id)?.cancel()
      filesDebounceTasks.removeValue(forKey: id)?.cancel()
      restartTasks.removeValue(forKey: id)?.cancel()
      pullRequestTasks.removeValue(forKey: id)?.cancel()
    }
    for watcher in treeWatchers.values {
      stopTreeWatcher(watcher)
    }
    headWatchers.removeAll()
    treeWatchers.removeAll()
    worktrees.removeAll()
    selectedWorktreeID = nil
    eventContinuation?.finish()
  }

  private func emit(_ event: WorktreeInfoWatcherClient.Event) {
    eventContinuation?.yield(event)
  }
}

private final class WorktreeInfoWatcherContext {
  weak var manager: WorktreeInfoWatcherManager?
  let worktreeID: Worktree.ID

  init(manager: WorktreeInfoWatcherManager, worktreeID: Worktree.ID) {
    self.manager = manager
    self.worktreeID = worktreeID
  }
}
