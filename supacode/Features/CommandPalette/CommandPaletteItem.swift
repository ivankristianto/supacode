struct CommandPaletteItem: Identifiable, Equatable {
  static let defaultPriorityTier = 100

  let id: String
  let title: String
  let subtitle: String?
  let kind: Kind
  let priorityTier: Int

  init(
    id: String,
    title: String,
    subtitle: String?,
    kind: Kind,
    priorityTier: Int = defaultPriorityTier
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.kind = kind
    self.priorityTier = priorityTier
  }

  enum Kind: Equatable {
    case checkForUpdates
    case openRepository
    case worktreeSelect(Worktree.ID)
    case openSettings
    case newWorktree
    case removeWorktree(Worktree.ID, Repository.ID)
    case archiveWorktree(Worktree.ID, Repository.ID)
    case refreshWorktrees
    case openPullRequest(Worktree.ID)
    case markPullRequestReady(Worktree.ID)
    case mergePullRequest(Worktree.ID)
    case copyCiFailureLogs(Worktree.ID)
    case rerunFailedJobs(Worktree.ID)
    case openFailingCheckDetails(Worktree.ID)
  }

  var isGlobal: Bool {
    switch kind {
    case .checkForUpdates, .openRepository, .openSettings, .newWorktree, .refreshWorktrees:
      return true
    case .openPullRequest,
      .markPullRequestReady,
      .mergePullRequest,
      .copyCiFailureLogs,
      .rerunFailedJobs,
      .openFailingCheckDetails:
      return true
    case .worktreeSelect, .removeWorktree, .archiveWorktree:
      return false
    }
  }
}
