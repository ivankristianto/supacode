import Darwin
import Dispatch
import Foundation

final class RepositoryChangeWatcher {
  private let queue: DispatchQueue
  private let onChange: @MainActor () -> Void
  private var sources: [DispatchSourceFileSystemObject] = []

  init(rootURL: URL, onChange: @escaping @MainActor () -> Void) {
    self.queue = DispatchQueue(label: "supacode.repository-change-watcher.\(UUID().uuidString)")
    self.onChange = onChange
    let gitDirectory = Self.gitDirectory(for: rootURL)
    let headsURL = gitDirectory.appending(path: "refs/heads", directoryHint: .isDirectory)
    let worktreesURL = gitDirectory.appending(path: "worktrees", directoryHint: .isDirectory)
    let packedRefsURL = gitDirectory.appending(path: "packed-refs", directoryHint: .notDirectory)
    [headsURL, worktreesURL, packedRefsURL].forEach { addSourceIfAvailable(for: $0) }
  }

  func stop() {
    sources.forEach { $0.cancel() }
    sources.removeAll()
  }

  private func addSourceIfAvailable(for url: URL) {
    let path = url.path(percentEncoded: false)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else { return }
    let descriptor = open(path, O_EVTONLY)
    guard descriptor >= 0 else { return }
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: descriptor,
      eventMask: [.write, .rename, .delete],
      queue: queue
    )
    source.setEventHandler { [onChange] in
      Task { @MainActor in
        onChange()
      }
    }
    source.setCancelHandler {
      close(descriptor)
    }
    sources.append(source)
    source.resume()
  }

  private static func gitDirectory(for rootURL: URL) -> URL {
    let dotGit = rootURL.appending(path: ".git", directoryHint: .notDirectory)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: dotGit.path(percentEncoded: false), isDirectory: &isDirectory) else {
      return dotGit
    }
    if isDirectory.boolValue {
      return dotGit
    }
    let contents = (try? String(contentsOf: dotGit, encoding: .utf8)) ?? ""
    let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("gitdir:") else {
      return dotGit
    }
    let rawPath = trimmed.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
    if rawPath.isEmpty {
      return dotGit
    }
    let resolved: URL
    if rawPath.hasPrefix("/") {
      resolved = URL(fileURLWithPath: String(rawPath))
    } else {
      resolved = rootURL.appending(path: String(rawPath), directoryHint: .isDirectory)
    }
    return resolved.standardizedFileURL
  }
}
