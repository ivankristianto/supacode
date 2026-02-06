import SwiftUI

struct ArchivedWorktreeRowView: View {
  let worktree: Worktree
  let info: WorktreeInfoEntry?
  let onUnarchive: () -> Void
  let onDelete: () -> Void

  var body: some View {
    let display = WorktreePullRequestDisplay(
      worktreeName: worktree.name,
      pullRequest: info?.pullRequest
    )
    let deleteShortcut = KeyboardShortcut(.delete, modifiers: [.command, .shift]).display
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        Text(worktree.name)
          .font(.headline)
        Spacer(minLength: 8)
        WorktreePullRequestAccessoryView(display: display)
      }
      HStack(spacing: 8) {
        if !worktree.detail.isEmpty {
          Text(worktree.detail)
            .foregroundStyle(.secondary)
            .monospaced()
        }
        if let createdAt = worktree.createdAt {
          Text("Created \(createdAt, style: .relative)")
            .foregroundStyle(.secondary)
        }
      }
      .font(.caption)
      HStack(spacing: 12) {
        Button("Unarchive", systemImage: "tray.and.arrow.up") {
          onUnarchive()
        }
        .help("Unarchive worktree")
        Button("Delete Worktree", role: .destructive) {
          onDelete()
        }
        .help("Delete Worktree (\(deleteShortcut))")
      }
      .font(.callout)
    }
  }
}
