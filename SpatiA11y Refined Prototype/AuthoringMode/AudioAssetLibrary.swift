import Foundation

enum AudioAssetLibrary {
    static let timpaniSounds: [SoundOption] = [
        // Ordered for widget slots 1-8.
        .init(category: .musical, displayName: "Bells", fileName: "bells_normalized.wav"),
        .init(category: .musical, displayName: "Jingle Hehe", fileName: "jingle_hehe_normalized.wav"),
        .init(category: .quirky, displayName: "Radar Girlie", fileName: "radar_girlie_normalized.wav"),
        .init(category: .quirky, displayName: "Opening Microwave", fileName: "opening_microwave_normalized.wav"),
        .init(category: .quirky, displayName: "Timbre 1", fileName: "timbre1_normalized.wav"),
        .init(category: .percussion, displayName: "Metal Clank", fileName: "metal_clank_normalized.wav"),
        .init(category: .musical, displayName: "Synth Blip Bounce", fileName: "synth_blip_bounce_normalized.wav"),
        .init(category: .percussion, displayName: "Wood Clunk", fileName: "wood_clunk_normalized.wav")
    ]

    static let allSounds: [SoundOption] = timpaniSounds

    static func sounds(for category: SoundCategory) -> [SoundOption] {
        allSounds.filter { $0.category == category }
    }

    static func defaultSound(for widget: WidgetID) -> SoundOption {
        timpaniSounds[(widget.index - 1) % timpaniSounds.count]
    }
}
