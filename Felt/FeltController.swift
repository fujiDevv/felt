import AppKit
import Combine

@MainActor
final class FeltController: ObservableObject {
    let settings = FeltSettings()
    let license = FeltLicense()
    private let events = EventMonitor()
    private let audio = FeltAudioEngine()
    private let calls = CallMonitor()
    private let overview = OverviewMonitor()
    private var subscriptions: Set<AnyCancellable> = []
    private var workspaceObservers: [NSObjectProtocol] = []
    @Published private(set) var inputActive = false
    @Published private(set) var permissionGranted = false
    @Published private(set) var lastGesture: String = "Try a pinch in another app"
    @Published private(set) var globalEvents = 0
    @Published private(set) var localEvents = 0
    @Published private(set) var monitoringStatus = "Monitoring not started"
    @Published private(set) var lastRawEvent = "No system gesture received"
    @Published private(set) var overviewStatus = "Overview monitoring not started"
    @Published private(set) var frontmostName = "current app"
    @Published private(set) var frontmostID: String?
    @Published private(set) var audioError: String?
    @Published private(set) var playbackStatus = "No playback requested"
    var outputDescription: String { audio.outputDescription }
    var onSound: ((GestureID) -> Void)?
    var sampleCount: Int { audio.sampleCount }
    var status: String {
        if !settings.enabled { return "Paused" }
        if let audioError { return audioError }
        if settings.quietOnCalls && inputActive { return "Quiet · Microphone in use" }
        if let frontmostID, settings.mutedBundleIDs.contains(frontmostID) { return "Quiet in \(frontmostName)" }
        return monitoringStatus
    }

    init() {
        settings.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        license.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        audio.onPlayback = { [weak self] in self?.playbackStatus = $0 }
        audio.onError = { [weak self] in self?.audioError = $0 }
        events.onStatus = { [weak self] in self?.monitoringStatus = $0 }
        events.onRawEvent = { [weak self] in self?.lastRawEvent = $0 }
        events.onEvent = { [weak self] global in
            if global { self?.globalEvents += 1 } else { self?.localEvents += 1 }
        }
        events.onGesture = { [weak self] gesture, pan, _ in self?.receive(gesture, pan: pan) }
        overview.onEnter = { [weak self] in
            self?.lastRawEvent = "Dock overview appeared · Window metadata"
            self?.receive(.spaceSwitch, pan: 0, title: "Mission Control / App Exposé")
        }
        overview.onStatus = { [weak self] in self?.overviewStatus = $0 }
        calls.onChange = { [weak self] active in
            guard let self, self.inputActive != active else { return }
            self.inputActive = active
        }
    }

    func start() {
        permissionGranted = CGPreflightListenEventAccess(); refreshFrontmost()
        events.start(); overview.start(); audio.start(); license.start()
        license.$purchased.sink { [weak self] purchased in
            guard let self else { return }
            #if !DEBUG
            if !purchased && self.settings.world != .paper { self.settings.world = .paper }
            #endif
        }.store(in: &subscriptions)
        updateCallMonitoring()
        settings.$quietOnCalls.dropFirst().sink { [weak self] enabled in
            if enabled { self?.calls.start() } else { self?.calls.stop(); self?.inputActive = false }
        }.store(in: &subscriptions)
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didWakeNotification] {
            workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refreshFrontmost(); self?.refreshPermission() }
            })
        }
        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.calls.stop(); self?.overview.stop() }
        })
        workspaceObservers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateCallMonitoring(); self?.overview.start() }
        })
    }

    func stop() {
        events.stop(); overview.stop(); calls.stop(); audio.stop(); license.stop()
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers.removeAll()
    }

    private func updateCallMonitoring() { if settings.quietOnCalls { calls.start() } else { calls.stop() } }
    private func refreshFrontmost() {
        guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
        frontmostName = app.localizedName ?? "current app"
        frontmostID = app.bundleIdentifier
    }
    func refreshPermission() {
        let granted = CGPreflightListenEventAccess()
        let changed = granted != permissionGranted
        permissionGranted = granted
        if changed { events.start() }
    }
    func openPermissionSettings() {
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
    func restartMonitoring() { permissionGranted = CGPreflightListenEventAccess(); events.start() }
    func toggleMuteCurrentApp() {
        guard let frontmostID else { return }
        if settings.mutedBundleIDs.contains(frontmostID) { settings.mutedBundleIDs.remove(frontmostID) }
        else { settings.mutedBundleIDs.insert(frontmostID) }
    }
    func select(_ world: SoundWorld) {
        if license.unlocked || world == .paper { settings.world = world }
        preview(world: world)
    }
    func testAudio() { playbackStatus = "Playing brief diagnostic tone"; audio.playDiagnosticTone(volume: settings.volume) }
    func restartAudio() { audio.restart(); playbackStatus = "Audio restarted · \(audio.outputDescription)" }
    func preview(world: SoundWorld? = nil) {
        playbackStatus = "Scheduling preview · \(audio.outputDescription)"
        // Preview is an explicit user action and remains available for locked worlds.
        if audio.preview(world: world ?? settings.world, volume: settings.volume) {
            lastGesture = "\((world ?? settings.world).title) preview"
            onSound?(.pinchOut)
        } else { playbackStatus = "Preview could not start" }
    }
    private func receive(_ gesture: GestureID, pan: Float, title: String? = nil) {
        refreshFrontmost()
        lastGesture = title ?? gesture.title
        guard settings.allows(gesture, licensed: license.unlocked, frontmostID: frontmostID, inputActive: inputActive) else { return }
        if audio.play(gesture, world: settings.world, volume: settings.volume, pan: pan) { onSound?(gesture) }
    }
}
