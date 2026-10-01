import Foundation

enum SoundWorld: String, CaseIterable, Identifiable, Codable {
    case paper, cloth, machine, toy
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var symbol: String {
        switch self {
        case .paper: "doc"
        case .cloth: "square.stack.3d.up"
        case .machine: "gearshape"
        case .toy: "circle.hexagongrid"
        }
    }
    var caption: String {
        switch self {
        case .paper: "Airy little touches."
        case .cloth: "Soft as a whisper."
        case .machine: "Smooth, rounded, delicate."
        case .toy: "Tiny bubbles of joy."
        }
    }
}

enum GestureID: String, CaseIterable, Codable, Identifiable {
    case pinchIn, pinchOut, pinchEnd, rotate, swipe, forceClick, spaceSwitch
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pinchIn: "Pinch in"
        case .pinchOut: "Pinch out"
        case .pinchEnd: "Pinch release"
        case .rotate: "Rotate"
        case .swipe: "Page swipe"
        case .forceClick: "Force Click"
        case .spaceSwitch: "Space switch"
        }
    }
    var isPinch: Bool { [.pinchIn, .pinchOut, .pinchEnd].contains(self) }
    var group: GestureGroup {
        switch self {
        case .pinchIn, .pinchOut, .pinchEnd: .pinch
        case .rotate: .rotate
        case .swipe: .swipe
        case .forceClick: .forceClick
        case .spaceSwitch: .spaces
        }
    }
}

enum GestureGroup: String, CaseIterable, Identifiable {
    case pinch, rotate, swipe, forceClick, spaces
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pinch: "Pinch"
        case .rotate: "Rotate"
        case .swipe: "Page swipe"
        case .forceClick: "Force Click"
        case .spaces: "System whooshes"
        }
    }
}

/// Value fixtures keep classification independent of AppKit and physical hardware.
struct GestureInput {
    enum Kind { case magnify, rotate, swipe, pressure, spaceSwitch }
    enum Phase { case began, changed, ended, cancelled, none }
    var kind: Kind
    var phase: Phase = .none
    var value: Double = 0
    var stage: Int = 0
    var timestamp: TimeInterval
}

struct GestureClassifier {
    private var pinchStarted = false
    private var rotation = 0.0
    private var rotationFired = false
    private var forceDown = false
    private var lastEmission: [GestureGroup: TimeInterval] = [:]

    mutating func reset() { self = Self() }

    mutating func beginSequence() {
        pinchStarted = false; rotation = 0; rotationFired = false
    }

    mutating func endSequence(timestamp: TimeInterval) -> GestureID? {
        let release = classify(GestureInput(kind: .magnify, phase: .ended, timestamp: timestamp))
        rotation = 0; rotationFired = false; forceDown = false
        return release
    }

    mutating func classify(_ input: GestureInput) -> GestureID? {
        var result: GestureID?
        switch input.kind {
        case .magnify:
            if input.phase == .began { pinchStarted = false }
            if input.phase == .cancelled { pinchStarted = false; return nil }
            if input.phase == .ended {
                if pinchStarted { result = .pinchEnd }
                pinchStarted = false
            } else if !pinchStarted, abs(input.value) > 0.0001 {
                pinchStarted = true
                result = input.value < 0 ? .pinchIn : .pinchOut
            }
        case .rotate:
            if input.phase == .began { rotation = 0; rotationFired = false }
            if input.phase == .ended || input.phase == .cancelled {
                rotation = 0; rotationFired = false; return nil
            }
            rotation += input.value
            if !rotationFired, abs(rotation) >= 8 { rotationFired = true; result = .rotate }
        case .swipe:
            if input.phase != .cancelled && input.phase != .ended && abs(input.value) > 0 { result = .swipe }
        case .pressure:
            if input.phase == .ended || input.phase == .cancelled || input.stage < 2 { forceDown = false }
            else if !forceDown { forceDown = true; result = .forceClick }
        case .spaceSwitch: result = .spaceSwitch
        }
        guard let result else { return nil }
        // A short pinch still needs its quiet release. Begin/end share no debounce.
        if result != .pinchEnd {
            if let last = lastEmission[result.group], input.timestamp - last < 0.08 { return nil }
            lastEmission[result.group] = input.timestamp
        }
        return result
    }
}
