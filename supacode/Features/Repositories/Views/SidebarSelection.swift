enum SidebarSelection: Hashable {
  case worktree(Worktree.ID)

  var worktreeID: Worktree.ID? {
    switch self {
    case .worktree(let id):
      return id
    }
  }
}
