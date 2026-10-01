import AppKit
import CoreGraphics
import OSLog

/// A public-window-metadata heuristic, not a documented Mission Control notification.
/// Only Dock windows are inspected; window titles and screen contents are never read.
@MainActor
final class OverviewMonitor {
    struct Window {
        let layer: Int
        let bounds: CGRect
        let alpha: Double
    }
    private var timer: Timer?
    private var wasVisible = false
    var onEnter: (() -> Void)?
    var onStatus: ((String) -> Void)?
    private var lastStatus = ""
    private var lastDockSnapshot = "No Dock overview observed"
    private let log = Logger(subsystem: "com.fujidevv.Felt", category: "Overview")

    private func report(_ status: String) {
        guard status != lastStatus else { return }
        lastStatus = status
        log.info("\(status, privacy: .public)")
        onStatus?(status)
    }

    static func isOverview(_ windows: [Window], displays: [CGRect]) -> Bool {
        // Observed locally: Dock's full-screen overview layer accompanied by app badges.
        // Requiring both avoids treating the ordinary Dock, desktop, or app switcher as an overview.
        let hasBadges = windows.contains { $0.layer == 17 && $0.alpha > 0.1 && $0.bounds.width > 0 && $0.bounds.height > 0 }
        return hasBadges && windows.contains { window in
            window.layer == 18 && window.alpha > 0.1 && displays.contains { display in
                let overlap = window.bounds.intersection(display)
                return overlap.width >= display.width * 0.9 && overlap.height >= display.height * 0.9
            }
        }
    }

    func start() {
        stop()
        wasVisible = overviewVisible()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let visible = self.overviewVisible()
                if visible && !self.wasVisible {
                    self.log.info("Overview entry detected")
                    self.onEnter?()
                }
                self.wasVisible = visible
            }
        }
        timer.tolerance = 0.03
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func overviewVisible() -> Bool {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            report("Overview: window metadata unavailable"); return false
        }
        let dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        let windows: [Window] = info.compactMap { entry in
            let isDock = dockPID.map { (entry[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == $0 }
                ?? (entry[kCGWindowOwnerName as String] as? String == "Dock")
            guard isDock,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { return nil }
            return Window(layer: layer, bounds: rect, alpha: entry[kCGWindowAlpha as String] as? Double ?? 0)
        }
        let displays = NSScreen.screens.compactMap { screen -> CGRect? in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            return CGDisplayBounds(id.uint32Value)
        }
        let visible = Self.isOverview(windows, displays: displays)
        let layers = Set(windows.map(\.layer)).sorted().map(String.init).joined(separator: ",")
        if !windows.isEmpty {
            lastDockSnapshot = "Last Dock layers: \(layers) · \(visible ? "Matched overview" : "No overview match")"
        }
        report("Overview: \(visible ? "visible" : "absent") · Dock windows \(windows.count)\n\(lastDockSnapshot)")
        return visible
    }
}
