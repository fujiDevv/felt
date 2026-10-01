import Foundation
import Combine

@MainActor
final class FeltSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var world: SoundWorld { didSet { defaults.set(world.rawValue, forKey: "world") } }
    @Published var volume: Double { didSet { defaults.set(volume, forKey: "volume") } }
    @Published var quietOnCalls: Bool { didSet { defaults.set(quietOnCalls, forKey: "quietOnCalls") } }
    @Published var disabledGroups: Set<String> { didSet { defaults.set(Array(disabledGroups), forKey: "disabledGroups") } }
    @Published var mutedBundleIDs: Set<String> { didSet { defaults.set(Array(mutedBundleIDs), forKey: "mutedBundleIDs") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        world = SoundWorld(rawValue: defaults.string(forKey: "world") ?? "") ?? .paper
        volume = defaults.object(forKey: "volume") as? Double ?? 0.45
        quietOnCalls = defaults.object(forKey: "quietOnCalls") as? Bool ?? true
        disabledGroups = Set(defaults.stringArray(forKey: "disabledGroups") ?? [])
        mutedBundleIDs = Set(defaults.stringArray(forKey: "mutedBundleIDs") ?? [])
    }

    func allows(_ gesture: GestureID, licensed: Bool, frontmostID: String?, inputActive: Bool) -> Bool {
        enabled && !disabledGroups.contains(gesture.group.rawValue)
            && !(frontmostID.map { mutedBundleIDs.contains($0) } ?? false)
            && !(quietOnCalls && inputActive)
            && (licensed || (world == .paper && gesture.isPinch))
    }

    func toggle(_ group: GestureGroup) {
        if disabledGroups.contains(group.rawValue) { disabledGroups.remove(group.rawValue) }
        else { disabledGroups.insert(group.rawValue) }
    }
}
