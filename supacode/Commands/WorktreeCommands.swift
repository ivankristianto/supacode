import Observation
import SwiftUI

struct WorktreeCommands: Commands {
  let repositoryStore: RepositoryStore
  @FocusedValue(\.openSelectedWorktreeAction) private var openSelectedWorktreeAction
  @FocusedValue(\.removeWorktreeAction) private var removeWorktreeAction

  var body: some Commands {
    @Bindable var repositoryStore = repositoryStore
    CommandGroup(replacing: .newItem) {
      Button("Open Repository...", systemImage: "folder") {
        repositoryStore.isOpenPanelPresented = true
      }
      .keyboardShortcut(
        AppShortcuts.openRepository.keyEquivalent,
        modifiers: AppShortcuts.openRepository.modifiers
      )
      .help("Open Repository (\(AppShortcuts.openRepository.display))")
      Button("Open Worktree") {
        openSelectedWorktreeAction?()
      }
      .keyboardShortcut(
        AppShortcuts.openFinder.keyEquivalent,
        modifiers: AppShortcuts.openFinder.modifiers
      )
      .help("Open Worktree (\(AppShortcuts.openFinder.display))")
      .disabled(openSelectedWorktreeAction == nil)
      Button("New Worktree", systemImage: "plus") {
        Task {
          await repositoryStore.createRandomWorktree()
        }
      }
      .keyboardShortcut(
        AppShortcuts.newWorktree.keyEquivalent, modifiers: AppShortcuts.newWorktree.modifiers
      )
      .help("New Worktree (\(AppShortcuts.newWorktree.display))")
      .disabled(!repositoryStore.canCreateWorktree)
      Button("Remove Worktree") {
        removeWorktreeAction?()
      }
      .keyboardShortcut(.delete, modifiers: .command)
      .help("Remove Worktree (⌘⌫)")
      .disabled(removeWorktreeAction == nil)
      Button("Refresh Worktrees") {
        Task {
          await repositoryStore.loadPersistedRepositories()
        }
      }
      .keyboardShortcut(
        AppShortcuts.refreshWorktrees.keyEquivalent,
        modifiers: AppShortcuts.refreshWorktrees.modifiers
      )
      .help("Refresh Worktrees (\(AppShortcuts.refreshWorktrees.display))")
    }
  }
}

private struct RemoveWorktreeActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

private struct OpenSelectedWorktreeActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var openSelectedWorktreeAction: (() -> Void)? {
    get { self[OpenSelectedWorktreeActionKey.self] }
    set { self[OpenSelectedWorktreeActionKey.self] = newValue }
  }

  var removeWorktreeAction: (() -> Void)? {
    get { self[RemoveWorktreeActionKey.self] }
    set { self[RemoveWorktreeActionKey.self] = newValue }
  }
}
