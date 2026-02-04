import ComposableArchitecture
import CustomDump
import Testing

@testable import supacode

@MainActor
struct CommandPaletteFeatureTests {
  @Test func showsGlobalItemsWhenQueryEmpty() {
    let openSettings = CommandPaletteItem(
      id: "global.open-settings",
      title: "Open Settings",
      subtitle: nil,
      kind: .openSettings
    )
    let newWorktree = CommandPaletteItem(
      id: "global.new-worktree",
      title: "New Worktree",
      subtitle: nil,
      kind: .newWorktree
    )
    let selectFox = CommandPaletteItem(
      id: "worktree.fox.select",
      title: "Repo / fox",
      subtitle: "main",
      kind: .worktreeSelect("wt-fox")
    )
    let runFox = CommandPaletteItem(
      id: "worktree.fox.run",
      title: "Repo / fox",
      subtitle: "Run - main",
      kind: .runWorktree("wt-fox")
    )
    let editorFox = CommandPaletteItem(
      id: "worktree.fox.editor",
      title: "Repo / fox",
      subtitle: "Open in Editor - main",
      kind: .openWorktreeInEditor("wt-fox")
    )
    let removeFox = CommandPaletteItem(
      id: "worktree.fox.remove",
      title: "Repo / fox",
      subtitle: "Remove Worktree - main",
      kind: .removeWorktree("wt-fox", "repo-fox")
    )

    expectNoDifference(
      CommandPaletteFeature.filterItems(
        items: [openSettings, newWorktree, selectFox, runFox, editorFox, removeFox],
        query: ""
      ),
      [openSettings, newWorktree]
    )
  }

  @Test func queryClearsSelectionWhenEmpty() async {
    var state = CommandPaletteFeature.State()
    state.query = "fox"
    state.selectedIndex = 1
    let store = TestStore(initialState: state) {
      CommandPaletteFeature()
    }

    await store.send(.binding(.set(\.query, ""))) {
      $0.query = ""
      $0.selectedIndex = nil
    }
  }

  @Test func queryMatchesGlobalItemsBeforeWorktrees() {
    let openSettings = CommandPaletteItem(
      id: "global.open-settings",
      title: "Open Settings",
      subtitle: nil,
      kind: .openSettings
    )
    let selectSettings = CommandPaletteItem(
      id: "worktree.settings.select",
      title: "Repo / settings",
      subtitle: "main",
      kind: .worktreeSelect("wt-settings")
    )

    expectNoDifference(
      CommandPaletteFeature.filterItems(items: [selectSettings, openSettings], query: "set"),
      [openSettings, selectSettings]
    )
  }

  @Test func activateDispatchesDelegate() async {
    var state = CommandPaletteFeature.State()
    state.isPresented = true
    state.query = "bear"
    state.selectedIndex = 1
    let store = TestStore(initialState: state) {
      CommandPaletteFeature()
    }

    await store.send(.activate(.runWorktree("wt-bear"))) {
      $0.isPresented = false
      $0.query = ""
      $0.selectedIndex = nil
    }
    await store.receive(.delegate(.runWorktree("wt-bear")))
  }
}
