import SwiftUI

struct GhosttyTerminalView: NSViewRepresentable {
    @ObservedObject var runtime: GhosttyRuntime

    func makeNSView(context: Context) -> GhosttySurfaceView {
        GhosttySurfaceView(runtime: runtime)
    }

    func updateNSView(_ view: GhosttySurfaceView, context: Context) {
        view.updateSurfaceSize()
    }
}
