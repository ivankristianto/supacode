import SwiftUI

struct WorktreeRow: View {
  let name: String
  let description: String?
  let isPinned: Bool
  let isMainWorktree: Bool
  let isLoading: Bool
  let taskStatus: WorktreeTaskStatus?
  let showsNotificationIndicator: Bool
  let shortcutHint: String?

  var body: some View {
    let showsSpinner = isLoading || taskStatus == .running
    let iconName = isMainWorktree ? "star.fill" : (isPinned ? "pin.fill" : "arrow.triangle.branch")
    HStack(alignment: .center) {
      ZStack {
        Image(systemName: iconName)
          .font(.caption)
          .foregroundStyle(.secondary)
          .opacity(showsSpinner ? 0 : 1)
          .accessibilityHidden(true)
        if showsSpinner {
          ProgressView()
            .controlSize(.small)
        }
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(name)
        if let description {
          Text(description)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 8)
      if showsNotificationIndicator {
        Image(systemName: "bell.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .help("Unread notifications")
          .accessibilityLabel("Unread notifications")
      }
      if let shortcutHint {
        ShortcutHintView(text: shortcutHint, color: .secondary)
      }
    }
  }
}
