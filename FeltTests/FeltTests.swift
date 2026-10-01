import AppKit
import Foundation
import Testing
@testable import Felt

@MainActor
struct FeltTests {
    @Test func overviewRequiresDockOverlayAndBadges() {
        let display = CGRect(x: 0, y: 0, width: 1710, height: 1112)
        let overlay = OverviewMonitor.Window(layer: 18, bounds: display, alpha: 1)
        let badge = OverviewMonitor.Window(layer: 17, bounds: CGRect(x: 100, y: 100, width: 100, height: 100), alpha: 1)
        #expect(OverviewMonitor.isOverview([overlay, badge], displays: [display]))
        #expect(!OverviewMonitor.isOverview([overlay], displays: [display]))
        #expect(!OverviewMonitor.isOverview([badge], displays: [display]))
        let small = OverviewMonitor.Window(layer: 18, bounds: CGRect(x: 0, y: 0, width: 500, height: 100), alpha: 1)
        #expect(!OverviewMonitor.isOverview([small, badge], displays: [display]))
        let hidden = OverviewMonitor.Window(layer: 18, bounds: display, alpha: 0)
        #expect(!OverviewMonitor.isOverview([hidden, badge], displays: [display]))
    }
    @Test func pinchWaitsForDirectionAndFiresOnce() {
        var classifier = GestureClassifier()
        #expect(classifier.classify(.init(kind: .magnify, phase: .began, timestamp: 1)) == nil)
        #expect(classifier.classify(.init(kind: .magnify, phase: .changed, value: -0.05, timestamp: 1.02)) == .pinchIn)
        #expect(classifier.classify(.init(kind: .magnify, phase: .changed, value: 0.05, timestamp: 1.1)) == nil)
        #expect(classifier.classify(.init(kind: .magnify, phase: .ended, timestamp: 1.2)) == .pinchEnd)
        #expect(classifier.classify(.init(kind: .magnify, phase: .ended, timestamp: 1.3)) == nil)
        #expect(classifier.classify(.init(kind: .magnify, phase: .began, value: 0.1, timestamp: 2)) == .pinchOut)
    }
    @Test func cancelledPinchDoesNotPlayRelease() {
        var classifier = GestureClassifier()
        #expect(classifier.classify(.init(kind: .magnify, phase: .began, value: 0.1, timestamp: 1)) == .pinchOut)
        #expect(classifier.classify(.init(kind: .magnify, phase: .cancelled, timestamp: 1.1)) == nil)
        #expect(classifier.classify(.init(kind: .magnify, phase: .ended, timestamp: 1.2)) == nil)
    }
    @Test func quickPinchStillReleases() {
        var classifier = GestureClassifier()
        #expect(classifier.classify(.init(kind: .magnify, phase: .began, value: 0.1, timestamp: 1)) == .pinchOut)
        #expect(classifier.classify(.init(kind: .magnify, phase: .ended, timestamp: 1.03)) == .pinchEnd)
    }
    @Test func rotateAccumulatesAndResets() {
        var classifier = GestureClassifier()
        #expect(classifier.classify(.init(kind: .rotate, phase: .began, value: 3, timestamp: 1)) == nil)
        #expect(classifier.classify(.init(kind: .rotate, phase: .changed, value: 5, timestamp: 1.1)) == .rotate)
        #expect(classifier.classify(.init(kind: .rotate, phase: .changed, value: 10, timestamp: 1.2)) == nil)
        #expect(classifier.classify(.init(kind: .rotate, phase: .ended, timestamp: 1.3)) == nil)
        #expect(classifier.classify(.init(kind: .rotate, phase: .began, value: -9, timestamp: 2)) == .rotate)
    }
    @Test func forceClickRequiresSecondStage() {
        var classifier = GestureClassifier()
        #expect(classifier.classify(.init(kind: .pressure, phase: .began, stage: 1, timestamp: 1)) == nil)
        #expect(classifier.classify(.init(kind: .pressure, phase: .changed, stage: 2, timestamp: 1.1)) == .forceClick)
        #expect(classifier.classify(.init(kind: .pressure, phase: .changed, stage: 2, timestamp: 1.2)) == nil)
        #expect(classifier.classify(.init(kind: .pressure, phase: .changed, stage: 1, timestamp: 1.3)) == nil)
        #expect(classifier.classify(.init(kind: .pressure, phase: .changed, stage: 2, timestamp: 1.4)) == .forceClick)
    }
    @Test func duplicateEventsAreDebounced() {
        var classifier = GestureClassifier()
        #expect(classifier.classify(.init(kind: .swipe, value: 1, timestamp: 1)) == .swipe)
        #expect(classifier.classify(.init(kind: .swipe, value: 1, timestamp: 1.02)) == nil)
        #expect(classifier.classify(.init(kind: .swipe, value: -1, timestamp: 1.2)) == .swipe)
        #expect(classifier.classify(.init(kind: .spaceSwitch, timestamp: 1.21)) == .spaceSwitch)
    }
    @Test func freeTierAndMutePolicy() throws {
        let name = "FeltTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = FeltSettings(defaults: defaults)
        #expect(settings.allows(.pinchIn, licensed: false, frontmostID: nil, inputActive: false))
        #expect(!settings.allows(.swipe, licensed: false, frontmostID: nil, inputActive: false))
        settings.world = .toy
        #expect(!settings.allows(.pinchIn, licensed: false, frontmostID: nil, inputActive: false))
        #expect(settings.allows(.swipe, licensed: true, frontmostID: nil, inputActive: false))
        settings.mutedBundleIDs.insert("test.app")
        #expect(!settings.allows(.swipe, licensed: true, frontmostID: "test.app", inputActive: false))
        #expect(!settings.allows(.swipe, licensed: true, frontmostID: nil, inputActive: true))
        settings.quietOnCalls = false
        #expect(settings.allows(.swipe, licensed: true, frontmostID: nil, inputActive: true))
        settings.toggle(.swipe)
        #expect(!settings.allows(.swipe, licensed: true, frontmostID: nil, inputActive: false))
        settings.enabled = false
        #expect(!settings.allows(.pinchIn, licensed: true, frontmostID: nil, inputActive: false))
    }
    @Test func settingsPersist() throws {
        let name = "FeltTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let settings = FeltSettings(defaults: defaults)
        settings.volume = 0.7; settings.world = .cloth; settings.enabled = false
        settings.mutedBundleIDs.insert("test.app"); settings.toggle(.rotate)
        let restored = FeltSettings(defaults: defaults)
        #expect(restored.volume == 0.7 && restored.world == .cloth && !restored.enabled)
        #expect(restored.mutedBundleIDs.contains("test.app"))
        #expect(restored.disabledGroups.contains("rotate"))
    }
    @Test func everySoundDecodes() {
        let audio = FeltAudioEngine()
        #expect(audio.sampleCount == SoundWorld.allCases.count * GestureID.allCases.count * 3)
        audio.stop()
    }
    @Test func audioGraphRendersAudibleSamples() throws {
        for world in SoundWorld.allCases {
            let audio = FeltAudioEngine(offline: true)
            #expect(audio.play(.pinchOut, world: world, volume: 0.6, pan: 0))
            #expect(try audio.renderedPeakForTesting() > 0.01)
            audio.stop()
        }
    }

    @Test func playbackReachesHardwareTimeline() async throws {
        let audio = FeltAudioEngine()
        #expect(audio.play(.pinchOut, world: .paper, volume: 0.6, pan: 0))
        try await Task.sleep(for: .milliseconds(700))
        #expect(audio.playbackCompletions > 0, "Audio must finish on the live output timeline")
        audio.stop()
    }

    @Test func independentPreviewAdvancesWithNonSilentAudio() async throws {
        let audio = FeltAudioEngine()
        #expect(audio.preview(world: .machine, volume: 0.6))
        try await Task.sleep(for: .milliseconds(50))
        #expect(audio.previewTime > 0)
        #expect(audio.previewPeak > -50)
        audio.stop()
    }

    @Test func genericGestureBoundariesResetPhaseLessPinch() {
        var classifier = GestureClassifier()
        classifier.beginSequence()
        #expect(classifier.classify(.init(kind: .magnify, value: 0.04, timestamp: 1)) == .pinchOut)
        #expect(classifier.endSequence(timestamp: 1.2) == .pinchEnd)
        #expect(classifier.endSequence(timestamp: 1.3) == nil)
        classifier.beginSequence()
        #expect(classifier.classify(.init(kind: .magnify, value: -0.04, timestamp: 2)) == .pinchIn)
    }
    @Test func eventTapMaskExcludesUnrelatedInput() {
        let mask = EventMonitor.gestureMask
        #expect(mask.contains(.magnify) && mask.contains(.gesture) && mask.contains(.endGesture))
        #expect(mask.intersection([.keyDown, .keyUp, .flagsChanged, .leftMouseDown, .mouseMoved, .scrollWheel]).isEmpty)
    }

}
