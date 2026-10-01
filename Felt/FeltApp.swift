import SwiftUI
import AppKit

@main
struct FeltApp: App {
    @NSApplicationDelegateAdaptor(FeltDelegate.self) private var delegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class FeltDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var item: NSStatusItem?
    private let popover = NSPopover()
    private var controller: FeltController?
    private var flashTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests host the app without installing system monitors or starting audio.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        NSApp.setActivationPolicy(.accessory)
        #if DEBUG
        if CommandLine.arguments.contains("--light-appearance") { NSApp.appearance = NSAppearance(named: .aqua) }
        if CommandLine.arguments.contains("--dark-appearance") { NSApp.appearance = NSAppearance(named: .darkAqua) }
        #endif
        let controller = FeltController()
        self.controller = controller
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item?.button?.image = Self.mark()
        item?.button?.toolTip = "Felt · Gesture sounds for Mac"
        item?.button?.target = self
        item?.button?.action = #selector(toggleMenu)
        let showForTesting = CommandLine.arguments.contains("--show-menu")
        // Keep the test popover open when XCTest briefly takes focus between launches.
        popover.behavior = showForTesting ? .applicationDefined : .transient
        popover.delegate = self
        #if DEBUG
        let previewScheme: ColorScheme? = CommandLine.arguments.contains("--light-appearance") ? .light
            : CommandLine.arguments.contains("--dark-appearance") ? .dark : nil
        #else
        let previewScheme: ColorScheme? = nil
        #endif
        let hosting = NSHostingController(rootView: ContentView(controller: controller).preferredColorScheme(previewScheme))
        if previewScheme != nil { hosting.view.appearance = NSApp.appearance }
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 380, height: min(610, (NSScreen.main?.visibleFrame.height ?? 690) - 80))
        controller.onSound = { [weak self] gesture in self?.flash(gesture) }
        controller.start()
        if showForTesting || !UserDefaults.standard.bool(forKey: "didShowFirstMenu") {
            if !showForTesting { UserDefaults.standard.set(true, forKey: "didShowFirstMenu") }
            DispatchQueue.main.async { [weak self] in
                // Launch Services may have already opened the menu through the reopen callback.
                guard let self, !self.popover.isShown else { return }
                self.toggleMenu()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !popover.isShown { toggleMenu() }
        return false
    }

    @objc private func toggleMenu() {
        guard let button = item?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            controller?.refreshPermission()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func flash(_ gesture: GestureID) {
        item?.button?.image = Self.mark(active: true)
        item?.button?.toolTip = "Felt · \(gesture.title)"
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            self?.item?.button?.image = Self.mark()
            self?.item?.button?.toolTip = "Felt · Gesture sounds for Mac"
        }
    }

    static func mark(active: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { bounds in
            (active ? NSColor.systemBlue : NSColor.labelColor).set()
            let pad = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 4, yRadius: 4)
            pad.lineWidth = 1.5
            pad.stroke()
            for x in [7.0, 12.0] {
                NSBezierPath(ovalIn: NSRect(x: x, y: 7, width: 2.5, height: 2.5)).fill()
            }
            return true
        }
        image.isTemplate = !active
        return image
    }

    func applicationWillTerminate(_ notification: Notification) { controller?.stop() }
}
