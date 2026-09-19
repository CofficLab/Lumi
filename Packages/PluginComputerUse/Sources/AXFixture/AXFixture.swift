import AppKit

// Dedicated test app: a window behind the user's work, never activated. The test
// runner launches/terminates this process only and controls no production apps.
@MainActor
final class FixtureDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 40, y: 40, width: 360, height: 200),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Lumi Accessibility Test"
        let button = NSButton(checkboxWithTitle: "Fixture Toggle", target: nil, action: nil)
        button.frame = NSRect(x: 24, y: 120, width: 220, height: 30)
        let text = NSTextField(frame: NSRect(x: 24, y: 70, width: 250, height: 26))
        text.stringValue = "original"
        text.setAccessibilityLabel("Fixture Text")
        let password = NSSecureTextField(frame: NSRect(x: 24, y: 20, width: 250, height: 26))
        password.stringValue = "fixture-secret-not-for-model"
        password.setAccessibilityLabel("Fixture Password")
        window.contentView?.addSubview(button)
        window.contentView?.addSubview(text)
        window.contentView?.addSubview(password)
        self.window = window
        window.orderBack(nil)
    }
}

@main
struct AXFixture {
    @MainActor static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = FixtureDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) {
        app.run()
        }
    }
}
