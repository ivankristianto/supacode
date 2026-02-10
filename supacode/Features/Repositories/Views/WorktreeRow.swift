import AppKit
import SwiftUI

struct WorktreeRow: View {
  let name: String
  let info: WorktreeInfoEntry?
  let showsPullRequestInfo: Bool
  let isPinned: Bool
  let isMainWorktree: Bool
  let isLoading: Bool
  let taskStatus: WorktreeTaskStatus?
  let isRunScriptRunning: Bool
  let showsNotificationIndicator: Bool
  let notifications: [WorktreeTerminalNotification]
  let onFocusNotification: (WorktreeTerminalNotification) -> Void
  let shortcutHint: String?
  let archiveAction: (() -> Void)?
  let showsBottomDivider: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let showsSpinner = isLoading || taskStatus == .running
    let branchIconName = isMainWorktree ? "star.fill" : (isPinned ? "pin.fill" : "arrow.triangle.branch")
    let display = WorktreePullRequestDisplay(
      worktreeName: name,
      pullRequest: showsPullRequestInfo ? info?.pullRequest : nil
    )
    let displayAddedLines = info?.addedLines
    let displayRemovedLines = info?.removedLines
    let mergeReadiness = pullRequestMergeReadiness(for: display.pullRequest)
    let hasChangeCounts = displayAddedLines != nil && displayRemovedLines != nil
    let archiveShortcut = KeyboardShortcut(.delete, modifiers: .command).display
    let showsMergedArchiveAction = display.pullRequestState == "MERGED" && archiveAction != nil
    let showsPullRequestTag = !showsMergedArchiveAction
      && display.pullRequest != nil
      && display.pullRequestBadgeStyle != nil
    let showsInfo = showsPullRequestTag || mergeReadiness != nil
    let nameColor = colorScheme == .dark ? Color.white : Color.primary
    VStack(alignment: .leading, spacing: 2) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        ZStack {
          if showsNotificationIndicator {
            NotificationPopoverButton(
              notifications: notifications,
              onFocusNotification: onFocusNotification
            ) {
              Image(systemName: "bell.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .accessibilityLabel("Unread notifications")
            }
            .opacity(showsSpinner ? 0 : 1)
          } else {
            Image(systemName: branchIconName)
              .font(.caption)
              .foregroundStyle(.secondary)
              .opacity(showsSpinner ? 0 : 1)
              .accessibilityHidden(true)
          }
          if showsSpinner {
            ProgressView()
              .controlSize(.small)
          }
        }
        .frame(width: 16, height: 16)
        .alignmentGuide(.firstTextBaseline) { _ in
          bodyFont.ascender
        }
        Text(name)
          .font(.body)
          .foregroundStyle(nameColor)
        Spacer(minLength: 8)
        if isRunScriptRunning {
          Image(systemName: "play.fill")
            .font(.caption)
            .foregroundStyle(.green)
            .help("Run script active")
            .accessibilityLabel("Run script active")
        }
        if hasChangeCounts, let displayAddedLines, let displayRemovedLines {
          WorktreeRowChangeCountView(
            addedLines: displayAddedLines,
            removedLines: displayRemovedLines
          )
        }
        if let archiveAction, display.pullRequestState == "MERGED" {
          Button {
            archiveAction()
          } label: {
            Image(systemName: "archivebox")
              .accessibilityLabel("Archive worktree")
          }
          .buttonStyle(.plain)
          .help("Archive Worktree (\(archiveShortcut))")
        }
        if let shortcutHint {
          ShortcutHintView(text: shortcutHint, color: .secondary)
        }
      }
      if showsInfo {
        WorktreeRowInfoView(
          display: display,
          showsPullRequestTag: showsPullRequestTag,
          mergeReadiness: mergeReadiness
        )
        .padding(.leading, 24)
      }
    }
    .padding(.vertical, 12)
    .overlay(alignment: .bottomLeading) {
      if showsBottomDivider {
        Rectangle()
          .fill(.separator)
          .frame(height: 0.5)
          .padding(.leading, 24)
      }
    }
  }

  private func pullRequestMergeReadiness(
    for pullRequest: GithubPullRequest?
  ) -> PullRequestMergeReadiness? {
    guard let pullRequest, pullRequest.state.uppercased() == "OPEN" else {
      return nil
    }
    return PullRequestMergeReadiness(pullRequest: pullRequest)
  }

  private var bodyFont: NSFont {
    NSFont.preferredFont(forTextStyle: .body)
  }
}

private struct WorktreeRowInfoView: View {
  let display: WorktreePullRequestDisplay
  let showsPullRequestTag: Bool
  let mergeReadiness: PullRequestMergeReadiness?

  var body: some View {
    HStack(spacing: 6) {
      if showsPullRequestTag {
        WorktreePullRequestAccessoryView(display: display)
      }
      if let mergeReadiness {
        if showsPullRequestTag {
          Text("•")
            .foregroundStyle(.secondary)
        }
        Text(mergeReadiness.label)
          .foregroundStyle(mergeReadiness.isBlocking ? .red : .green)
      }
    }
    .font(.caption)
    .lineLimit(1)
    .frame(minHeight: 14)
  }
}

private struct WorktreeRowChangeCountView: View {
  let addedLines: Int
  let removedLines: Int

  var body: some View {
    HStack(spacing: 4) {
      Text("+\(addedLines)")
        .foregroundStyle(.green)
      Text("-\(removedLines)")
        .foregroundStyle(.red)
    }
    .font(.caption)
    .lineLimit(1)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .overlay {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .stroke(.tertiary, lineWidth: 1)
    }
    .monospacedDigit()
  }
}
