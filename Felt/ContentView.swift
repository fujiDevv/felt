import SwiftUI
import AppKit

private enum FeltPanel: String, CaseIterable { case sound = "Sound", settings = "Settings" }

struct ContentView: View {
    @ObservedObject var controller: FeltController
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panel: FeltPanel = .sound
    @State private var showDiagnostics = false
    private let actionBlue = Color(red: 0.18, green: 0.36, blue: 0.85)
    private var blue: Color { colorScheme == .dark ? Color(red: 0.47, green: 0.65, blue: 1) : actionBlue }
    private var settings: FeltSettings { controller.settings }
    private var license: FeltLicense { controller.license }
    private var surface: Color { Color(nsColor: .controlBackgroundColor) }
    private var hairline: Color { Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.07) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if showDiagnostics { diagnostics }
                    else {
                        Picker("Panel", selection: $panel) {
                            ForEach(FeltPanel.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented).labelsHidden().accessibilityLabel("Felt panel")
                        if panel == .sound { soundPanel } else { settingsPanel }
                    }
                    if let message = license.message {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(20)
            }.scrollIndicators(.automatic)
            footer
        }
        .frame(width: 380, height: min(610, (NSScreen.main?.visibleFrame.height ?? 690) - 80))
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Felt content")
        .tint(actionBlue)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: panel)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(nsImage: FeltDelegate.mark()).renderingMode(.template)
                    .resizable().scaledToFit().frame(width: 22, height: 21)
                    .foregroundStyle(.white).padding(9)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                Text("felt").font(.system(size: 23, weight: .semibold)).tracking(-0.8)
                Spacer()
                Toggle("Enable Felt", isOn: Binding(get: { settings.enabled }, set: { settings.enabled = $0 }))
                    .labelsHidden().toggleStyle(.switch).tint(Color(red: 0.39, green: 0.63, blue: 0.95))
                    .accessibilityLabel("Enable Felt")
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("A softer touch.").font(.system(size: 26, weight: .semibold)).tracking(-0.8)
                Text("Tiny sounds for everyday gestures.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.85))
            }
        }
        .foregroundStyle(.white).padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.16, green: 0.25, blue: 0.69), Color(red: 0.20, green: 0.43, blue: 0.83)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var soundPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Sound world").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Soft collection").font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                ForEach(SoundWorld.allCases) { world in
                    Button { controller.select(world) } label: {
                        VStack(spacing: 10) {
                            Image(systemName: world.symbol).font(.system(size: 21, weight: .light))
                            HStack(spacing: 3) {
                                Text(world.title).font(.system(size: 11, weight: .medium))
                                if !license.unlocked && world != .paper { Image(systemName: "lock.fill").font(.system(size: 7)) }
                            }
                        }
                        .frame(maxWidth: .infinity).frame(height: 80)
                        .foregroundStyle(settings.world == world ? blue : Color.primary)
                        .background(settings.world == world ? blue.opacity(colorScheme == .dark ? 0.2 : 0.08) : surface, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(settings.world == world ? blue.opacity(0.7) : hairline, lineWidth: 1))
                    }.buttonStyle(.plain).accessibilityLabel("\(world.title) sound world")
                }
            }
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.world.caption).font(.system(size: 12, weight: .medium))
                        Text("Brief, gentle, and close.").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { controller.preview() } label: {
                        Text("Preview").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 10).background(actionBlue, in: Capsule())
                    }.buttonStyle(.plain).help("Preview selected sound world").accessibilityLabel("Preview sound")
                }
                HStack(spacing: 4) {
                    Image(systemName: "waveform").font(.system(size: 14)).foregroundStyle(blue)
                    Text("No long tails").font(.system(size: 11)).foregroundStyle(.secondary).padding(.leading, 4)
                    Spacer()
                    Text("60–220 ms").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }.frame(height: 25)
            }.padding(16).background(surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(hairline))
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Volume", systemImage: "speaker.wave.2").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(Int(settings.volume * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                Slider(value: Binding(get: { settings.volume }, set: { settings.volume = $0 }), in: 0...1)
                    .accessibilityLabel("Volume")
            }
            if !controller.permissionGranted {
                Button(action: controller.openPermissionSettings) {
                    HStack(spacing: 10) {
                        Image(systemName: "hand.point.up.left").font(.system(size: 17))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Enable gestures in other apps").font(.system(size: 12, weight: .medium))
                            Text("Allow Felt in Input Monitoring.").font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 10))
                    }.padding(12).background(blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).accessibilityLabel("Turn on Input Monitoring")
            }
            if !license.unlocked {
                Button("Unlock every world · \(license.price)") { Task { await license.purchase() } }
                    .buttonStyle(.borderedProminent).disabled(license.busy)
                Text("One-time purchase").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep it quiet").font(.system(size: 14, weight: .semibold))
                Toggle("Quiet on calls", isOn: Binding(get: { settings.quietOnCalls }, set: { settings.quietOnCalls = $0 }))
                    .toggleStyle(.switch).font(.system(size: 12))
                    .accessibilityLabel("Quiet on calls").accessibilityIdentifier("Quiet on calls")
                Text("Felt rests while an app uses your microphone.").font(.system(size: 11)).foregroundStyle(.secondary)
                Button { controller.toggleMuteCurrentApp() } label: {
                    Label(settings.mutedBundleIDs.contains(controller.frontmostID ?? "") ? "Unmute \(controller.frontmostName)" : "Mute \(controller.frontmostName)", systemImage: "speaker.slash")
                        .lineLimit(1)
                }.buttonStyle(.bordered).disabled(controller.frontmostID == nil)
                ForEach(settings.mutedBundleIDs.sorted(), id: \.self) { id in
                    HStack {
                        Text(appName(id)).font(.caption).lineLimit(1)
                        Spacer()
                        Button("Unmute") { settings.mutedBundleIDs.remove(id) }.buttonStyle(.borderless).font(.caption)
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                Text("Gestures").font(.system(size: 14, weight: .semibold))
                ForEach(GestureGroup.allCases) { group in
                    Toggle(group.title, isOn: Binding(get: { !settings.disabledGroups.contains(group.rawValue) }, set: { _ in settings.toggle(group) }))
                        .toggleStyle(.switch).font(.system(size: 12))
                        .disabled(!license.unlocked && group != .pinch)
                }
                Text("Mission Control and App Exposé detection is experimental. Space switches use macOS notifications.")
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button { showDiagnostics = false } label: { Label("Back to Felt", systemImage: "chevron.left") }.buttonStyle(.plain)
            Text("Monitoring details").font(.system(size: 18, weight: .semibold))
            Text(controller.lastGesture).font(.system(size: 13, weight: .medium)).foregroundStyle(blue)
            Text("Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")")
            Text("Global events: \(controller.globalEvents) · Local: \(controller.localEvents)")
            Text("\(controller.sampleCount) samples loaded")
            Text(controller.monitoringStatus)
            Text(controller.lastRawEvent)
            Text(controller.overviewStatus)
            Divider()
            Button("Play diagnostic tone", action: controller.testAudio).buttonStyle(.bordered)
            Text(controller.playbackStatus)
            Text(controller.outputDescription)
            HStack {
                Button("Restart audio", action: controller.restartAudio)
                Button("Restart monitoring", action: controller.restartMonitoring)
            }.buttonStyle(.bordered)
            Text("Pinch in Safari, then reopen these details to check event delivery. Mission Control uses a separate Dock-window heuristic.")
                .foregroundStyle(.secondary)
        }.font(.system(size: 11)).fixedSize(horizontal: false, vertical: true)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: settings.enabled ? "waveform" : "pause.circle").font(.system(size: 11)).foregroundStyle(blue)
            Text(controller.status).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
            Menu {
                Button("Monitoring details") { showDiagnostics = true }
                Button("Restore Purchases") { Task { await license.restore() } }
                Button("About Felt") { NSApp.orderFrontStandardAboutPanel(options: [.credits: NSAttributedString(string: "Soft gesture sounds for Mac.\nAudio generated with ElevenLabs.\nGestures stay on your Mac.")]) }
                Divider()
                Button("Quit Felt") { NSApp.terminate(nil) }.keyboardShortcut("q")
            } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("More options")
        }.padding(.horizontal, 20).padding(.vertical, 13)
            .background(surface).overlay(alignment: .top) { hairline.frame(height: 1) }
    }

    private func appName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return FileManager.default.displayName(atPath: url.path)
    }
}
