import AppKit
import CoreGraphics

@MainActor
final class EventMonitor {
    private var global: Any?
    private var local: Any?
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var spaceObserver: NSObjectProtocol?
    private var classifier = GestureClassifier()
    var onGesture: ((GestureID, Float, Bool) -> Void)?
    var onEvent: ((Bool) -> Void)?
    var onRawEvent: ((String) -> Void)?
    var onStatus: ((String) -> Void)?
    var installed: Bool { tap != nil }

    // AppKit defines the gesture mask bits missing from CGEventType's named cases.
    // Observe only these bits: no keyboard, clicks, movement, or scroll-wheel input.
    static let gestureMask: NSEvent.EventTypeMask = [.gesture, .magnify, .rotate, .swipe, .pressure, .beginGesture, .endGesture]

    func start() {
        stop()
        if CGPreflightListenEventAccess() {
            let context = Unmanaged.passUnretained(self).toOpaque()
            tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                    options: .listenOnly, eventsOfInterest: CGEventMask(Self.gestureMask.rawValue),
                                    callback: { _, type, cgEvent, context in
                guard let context else { return Unmanaged.passUnretained(cgEvent) }
                // This tap is installed exclusively on the main run loop.
                MainActor.assumeIsolated {
                    let monitor = Unmanaged<EventMonitor>.fromOpaque(context).takeUnretainedValue()
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        if let tap = monitor.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                        monitor.onStatus?("Gesture tap restarted after interruption")
                    } else {
                        monitor.onEvent?(true)
                        if let event = NSEvent(cgEvent: cgEvent) {
                            monitor.onRawEvent?("Quartz \(type.rawValue) → AppKit \(event.type.rawValue)")
                            monitor.handle(event, global: true, countEvent: false)
                        } else { monitor.onRawEvent?("Quartz \(type.rawValue): no AppKit gesture") }
                    }
                }
                // Listen-only: always preserve the system event.
                return Unmanaged.passUnretained(cgEvent)
            }, userInfo: context)
            if let tap, let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) {
                tapSource = source
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                onStatus?("System gesture tap active")
            } else {
                if let tap { CFMachPortInvalidate(tap) }
                tap = nil
                onStatus?("System gesture tap unavailable")
            }
        } else { onStatus?("Input Monitoring required") }

        // Keep the AppKit path as a fallback when the session tap is unavailable.
        if tap == nil {
            global = NSEvent.addGlobalMonitorForEvents(matching: Self.gestureMask) { [weak self] event in
                self?.handle(event, global: true)
            }
            local = NSEvent.addLocalMonitorForEvents(matching: Self.gestureMask) { [weak self] event in
                self?.handle(event, global: false)
                return event
            }
        }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let gesture = self.classifier.classify(
                    GestureInput(kind: .spaceSwitch, timestamp: ProcessInfo.processInfo.systemUptime)
                ) else { return }
                self.onGesture?(gesture, 0, true)
            }
        }
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil; tapSource = nil
        if let global { NSEvent.removeMonitor(global) }
        if let local { NSEvent.removeMonitor(local) }
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        global = nil; local = nil; spaceObserver = nil
        classifier.reset()
    }

    private func handle(_ event: NSEvent, global: Bool, countEvent: Bool = true) {
        if countEvent { onEvent?(global); onRawEvent?("AppKit \(event.type.rawValue)") }
        if event.type == .beginGesture { classifier.beginSequence(); return }
        if event.type == .endGesture {
            if let gesture = classifier.endSequence(timestamp: event.timestamp) { onGesture?(gesture, pan(), global) }
            return
        }
        let kind: GestureInput.Kind
        let value: Double
        switch event.type {
        case .magnify: kind = .magnify; value = event.magnification
        case .rotate: kind = .rotate; value = Double(event.rotation)
        case .swipe: kind = .swipe; value = Double(event.deltaX != 0 ? event.deltaX : event.deltaY)
        case .pressure: kind = .pressure; value = Double(event.pressure)
        default: return
        }
        let phase: GestureInput.Phase
        if event.phase.contains(.cancelled) { phase = .cancelled }
        else if event.phase.contains(.ended) { phase = .ended }
        else if event.phase.contains(.began) { phase = .began }
        else if event.phase.contains(.changed) { phase = .changed }
        else { phase = .none }
        let input = GestureInput(kind: kind, phase: phase, value: value,
                                 stage: kind == .pressure ? event.stage : 0, timestamp: event.timestamp)
        guard let gesture = classifier.classify(input) else { return }
        onGesture?(gesture, pan(), global)
    }

    private func pan() -> Float {
        let cursor = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(cursor) }
        let value = screen.map { Float(((cursor.x - $0.frame.minX) / $0.frame.width) * 2 - 1) } ?? 0
        return max(-1, min(1, value))
    }
}
