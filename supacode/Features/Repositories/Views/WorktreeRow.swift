import SwiftUI

struct WorktreeRow: View {
  let name: String
  let isPinned: Bool
  let isMainWorktree: Bool
  let isLoading: Bool

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      ZStack {
        Image(systemName: "arrow.triangle.branch")
          .font(.caption)
          .foregroundStyle(.secondary)
          .opacity(isLoading ? 0 : 1)
          .accessibilityHidden(true)
        if isLoading {
          ProgressView()
            .controlSize(.small)
        }
      }
      Text(name)
      Spacer(minLength: 8)
      if isMainWorktree {
        Image(systemName: "star.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      if isPinned {
        Image(systemName: "pin.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
    }
  }
}
