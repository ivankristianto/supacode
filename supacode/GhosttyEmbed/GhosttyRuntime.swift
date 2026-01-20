import AppKit
import Combine
import GhosttyKit

final class GhosttyRuntime: ObservableObject {
    private var config: ghostty_config_t?
    private(set) var app: ghostty_app_t?
    private var observers: [NSObjectProtocol] = []

    init() {
        guard let config = ghostty_config_new() else {
            preconditionFailure("ghostty_config_new failed")
        }
        self.config = config
        ghostty_config_load_default_files(config)
        ghostty_config_load_recursive_files(config)
        ghostty_config_finalize(config)

        var runtimeConfig = ghostty_runtime_config_s(
            userdata: Unmanaged.passUnretained(self).toOpaque(),
            supports_selection_clipboard: false,
            wakeup_cb: { userdata in GhosttyRuntime.wakeup(userdata) },
            action_cb: { app, target, action in
                guard let app else { return false }
                return GhosttyRuntime.action(app, target: target, action: action)
            },
            read_clipboard_cb: { userdata, loc, state in GhosttyRuntime.readClipboard(userdata, location: loc, state: state) },
            confirm_read_clipboard_cb: { userdata, str, state, request in
                GhosttyRuntime.confirmReadClipboard(userdata, string: str, state: state, request: request)
            },
            write_clipboard_cb: { userdata, loc, content, len, confirm in
                GhosttyRuntime.writeClipboard(userdata, location: loc, content: content, len: len, confirm: confirm)
            },
            close_surface_cb: { userdata, processAlive in GhosttyRuntime.closeSurface(userdata, processAlive: processAlive) }
        )

        guard let app = ghostty_app_new(&runtimeConfig, config) else {
            preconditionFailure("ghostty_app_new failed")
        }
        self.app = app

        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setAppFocus(true)
        })
        observers.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setAppFocus(false)
        })
    }

    deinit {
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        if let app {
            ghostty_app_free(app)
        }
        if let config {
            ghostty_config_free(config)
        }
    }

    func setAppFocus(_ focused: Bool) {
        if let app {
            ghostty_app_set_focus(app, focused)
        }
    }

    func tick() {
        if let app {
            ghostty_app_tick(app)
        }
    }

    private static func runtime(from userdata: UnsafeMutableRawPointer?) -> GhosttyRuntime? {
        guard let userdata else { return nil }
        return Unmanaged<GhosttyRuntime>.fromOpaque(userdata).takeUnretainedValue()
    }

    private static func surfaceView(from userdata: UnsafeMutableRawPointer?) -> GhosttySurfaceView? {
        guard let userdata else { return nil }
        return Unmanaged<GhosttySurfaceView>.fromOpaque(userdata).takeUnretainedValue()
    }

    private static func wakeup(_ userdata: UnsafeMutableRawPointer?) {
        guard let runtime = runtime(from: userdata) else { return }
        DispatchQueue.main.async {
            runtime.tick()
        }
    }

    private static func action(_ app: ghostty_app_t, target: ghostty_target_s, action: ghostty_action_s) -> Bool {
        return false
    }

    private static func readClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        state: UnsafeMutableRawPointer?
    ) {
        guard let surfaceView = surfaceView(from: userdata), let surface = surfaceView.surface else { return }
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            let value = pasteboard.string(forType: .string) ?? ""
            value.withCString { ptr in
                ghostty_surface_complete_clipboard_request(surface, ptr, state, false)
            }
        }
    }

    private static func confirmReadClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        string: UnsafePointer<CChar>?,
        state: UnsafeMutableRawPointer?,
        request: ghostty_clipboard_request_e
    ) {
        guard let surfaceView = surfaceView(from: userdata), let surface = surfaceView.surface else { return }
        guard let string else { return }
        DispatchQueue.main.async {
            ghostty_surface_complete_clipboard_request(surface, string, state, true)
        }
    }

    private static func writeClipboard(
        _ userdata: UnsafeMutableRawPointer?,
        location: ghostty_clipboard_e,
        content: UnsafePointer<ghostty_clipboard_content_s>?,
        len: Int,
        confirm: Bool
    ) {
        guard let content, len > 0 else { return }
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            var stringValue: String?
            for i in 0..<len {
                let item = content.advanced(by: i).pointee
                if let mime = item.mime, let data = item.data, String(cString: mime) == "text/plain" {
                    stringValue = String(cString: data)
                    break
                }
            }
            if let stringValue {
                pasteboard.setString(stringValue, forType: .string)
            }
        }
    }

    private static func closeSurface(_ userdata: UnsafeMutableRawPointer?, processAlive: Bool) {
        guard let surfaceView = surfaceView(from: userdata) else { return }
        surfaceView.closeSurface()
    }
}
