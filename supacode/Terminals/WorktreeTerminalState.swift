import Bonsplit
import Foundation

@MainActor
final class WorktreeTerminalState: BonsplitDelegate {
    let controller: BonsplitController
    private let runtime: GhosttyRuntime
    private let worktree: Worktree
    private var surfaces: [TabID: GhosttySurfaceView] = [:]

    init(runtime: GhosttyRuntime, worktree: Worktree) {
        self.runtime = runtime
        self.worktree = worktree
        let configuration = BonsplitConfiguration(
            allowSplits: false,
            allowCloseTabs: true,
            allowCloseLastPane: false,
            allowTabReordering: true,
            allowCrossPaneTabMove: false,
            autoCloseEmptyPanes: false,
            contentViewLifecycle: .keepAllAlive,
            newTabPosition: .current
        )
        controller = BonsplitController(configuration: configuration)
        controller.delegate = self
    }

    func ensureInitialTab() {
        let tabIds = controller.allTabIds
        if tabIds.isEmpty {
            _ = createTab(in: nil)
            return
        }
        if tabIds.count == 1, let tabId = tabIds.first, let tab = controller.tab(tabId), tab.title == "Welcome" {
            let title = "\(worktree.name) \(nextTabIndex())"
            controller.updateTab(tabId, title: title, icon: "terminal")
        }
    }

    @discardableResult
    func createTab(in pane: PaneID?) -> TabID? {
        let title = "\(worktree.name) \(nextTabIndex())"
        return controller.createTab(
            title: title,
            icon: "terminal",
            inPane: pane
        )
    }

    func surfaceView(for tabId: TabID) -> GhosttySurfaceView {
        if let existing = surfaces[tabId] {
            return existing
        }
        let view = GhosttySurfaceView(runtime: runtime, workingDirectory: worktree.workingDirectory)
        surfaces[tabId] = view
        return view
    }

    func closeAllSurfaces() {
        for surface in surfaces.values {
            surface.closeSurface()
        }
        surfaces.removeAll()
    }

    func splitTabBar(_ controller: BonsplitController, didCloseTab tabId: TabID, fromPane pane: PaneID) {
        guard let surface = surfaces.removeValue(forKey: tabId) else { return }
        surface.closeSurface()
    }

    private func nextTabIndex() -> Int {
        let prefix = "\(worktree.name) "
        var maxIndex = 0
        for tabId in controller.allTabIds {
            guard let title = controller.tab(tabId)?.title else { continue }
            guard title.hasPrefix(prefix) else { continue }
            let suffix = title.dropFirst(prefix.count)
            guard let value = Int(suffix) else { continue }
            maxIndex = max(maxIndex, value)
        }
        return maxIndex + 1
    }
}
