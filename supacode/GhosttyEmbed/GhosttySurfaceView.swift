import AppKit
import GhosttyKit

final class GhosttySurfaceView: NSView {
    private let runtime: GhosttyRuntime
    private(set) var surface: ghostty_surface_t?
    private var trackingArea: NSTrackingArea?
    private var lastBackingSize: CGSize = .zero
    private var lastModifierFlags: NSEvent.ModifierFlags = []

    override var acceptsFirstResponder: Bool { true }

    init(runtime: GhosttyRuntime) {
        self.runtime = runtime
        super.init(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        wantsLayer = true
        createSurface()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        closeSurface()
    }

    func closeSurface() {
        if let surface {
            ghostty_surface_free(surface)
            self.surface = nil
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentScale()
        updateSurfaceSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentScale()
        updateSurfaceSize()
    }

    override func layout() {
        super.layout()
        updateSurfaceSize()
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            setSurfaceFocus(true)
        }
        return result
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            setSurfaceFocus(false)
        }
        return result
    }

    override func keyDown(with event: NSEvent) {
        let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
        sendKey(event: event, action: action)
    }

    override func keyUp(with event: NSEvent) {
        sendKey(event: event, action: GHOSTTY_ACTION_RELEASE)
    }

    override func flagsChanged(with event: NSEvent) {
        let relevant: NSEvent.ModifierFlags = [.shift, .control, .option, .command, .capsLock]
        let newFlags = event.modifierFlags.intersection(relevant)
        let oldFlags = lastModifierFlags
        lastModifierFlags = newFlags
        let pressed = newFlags.subtracting(oldFlags)
        let released = oldFlags.subtracting(newFlags)
        if !pressed.isEmpty {
            sendKey(event: event, action: GHOSTTY_ACTION_PRESS)
        }
        if !released.isEmpty {
            sendKey(event: event, action: GHOSTTY_ACTION_RELEASE)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        sendMousePosition(event)
    }

    override func mouseDown(with event: NSEvent) {
        sendMouseButton(event, state: GHOSTTY_MOUSE_PRESS, button: GHOSTTY_MOUSE_LEFT)
    }

    override func mouseUp(with event: NSEvent) {
        sendMouseButton(event, state: GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_LEFT)
    }

    override func rightMouseDown(with event: NSEvent) {
        sendMouseButton(event, state: GHOSTTY_MOUSE_PRESS, button: GHOSTTY_MOUSE_RIGHT)
    }

    override func rightMouseUp(with event: NSEvent) {
        sendMouseButton(event, state: GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_RIGHT)
    }

    override func otherMouseDown(with event: NSEvent) {
        sendMouseButton(event, state: GHOSTTY_MOUSE_PRESS, button: GHOSTTY_MOUSE_MIDDLE)
    }

    override func otherMouseUp(with event: NSEvent) {
        sendMouseButton(event, state: GHOSTTY_MOUSE_RELEASE, button: GHOSTTY_MOUSE_MIDDLE)
    }

    override func mouseDragged(with event: NSEvent) {
        sendMousePosition(event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        sendMousePosition(event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        sendMousePosition(event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX, event.scrollingDeltaY, 0)
    }

    func updateSurfaceSize() {
        guard let surface else { return }
        let backingSize = convertToBacking(bounds.size)
        if backingSize == lastBackingSize {
            return
        }
        lastBackingSize = backingSize
        let width = UInt32(max(1, Int(backingSize.width.rounded(.down))))
        let height = UInt32(max(1, Int(backingSize.height.rounded(.down))))
        ghostty_surface_set_size(surface, width, height)
    }

    private func createSurface() {
        guard let app = runtime.app else { return }
        var config = ghostty_surface_config_new()
        config.userdata = Unmanaged.passUnretained(self).toOpaque()
        config.platform_tag = GHOSTTY_PLATFORM_MACOS
        config.platform = ghostty_platform_u(macos: ghostty_platform_macos_s(
            nsview: Unmanaged.passUnretained(self).toOpaque()
        ))
        config.scale_factor = backingScaleFactor()
        config.context = GHOSTTY_SURFACE_CONTEXT_WINDOW
        surface = ghostty_surface_new(app, &config)
        updateSurfaceSize()
    }

    private func updateContentScale() {
        guard let surface else { return }
        let scale = backingScaleFactor()
        ghostty_surface_set_content_scale(surface, scale, scale)
    }

    private func backingScaleFactor() -> Double {
        if let window {
            return window.backingScaleFactor
        }
        if let screen = NSScreen.main {
            return screen.backingScaleFactor
        }
        return 2.0
    }

    private func setSurfaceFocus(_ focused: Bool) {
        guard let surface else { return }
        ghostty_surface_set_focus(surface, focused)
    }

    private func sendKey(event: NSEvent, action: ghostty_input_action_e) {
        guard let surface else { return }
        var key = ghostty_input_key_s()
        key.action = action
        key.keycode = UInt32(event.keyCode)
        key.mods = ghosttyMods(event.modifierFlags)
        key.consumed_mods = key.mods
        key.unshifted_codepoint = unshiftedCodepoint(for: event)
        key.composing = false
        if let text = event.characters, !text.isEmpty {
            text.withCString { ptr in
                key.text = ptr
                _ = ghostty_surface_key(surface, key)
            }
        } else {
            key.text = nil
            _ = ghostty_surface_key(surface, key)
        }
    }

    private func unshiftedCodepoint(for event: NSEvent) -> UInt32 {
        if let chars = event.charactersIgnoringModifiers,
           let scalar = chars.unicodeScalars.first {
            return scalar.value
        }
        return 0
    }

    private func sendMousePosition(_ event: NSEvent) {
        guard let surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        let backing = convertToBacking(point)
        let mods = ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_pos(surface, backing.x, backing.y, mods)
    }

    private func sendMouseButton(
        _ event: NSEvent,
        state: ghostty_input_mouse_state_e,
        button: ghostty_input_mouse_button_e
    ) {
        guard let surface else { return }
        let mods = ghosttyMods(event.modifierFlags)
        ghostty_surface_mouse_button(surface, state, button, mods)
    }

    private func ghosttyMods(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var mods: UInt32 = GHOSTTY_MODS_NONE.rawValue
        if flags.contains(.shift) { mods |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { mods |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { mods |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { mods |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { mods |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(mods)
    }

}
