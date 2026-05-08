import Foundation

enum AudioAssetLibrary {
    static let timpaniSounds: [SoundOption] = [
        // Ordered for widget slots 1-8.
        .init(category: .musical, displayName: "Bells", fileName: "bells.wav"),
        .init(category: .musical, displayName: "Jingle Hehe", fileName: "jingle_hehe.wav"),
        .init(category: .quirky, displayName: "Radar Girlie", fileName: "radar_girlie.wav"),
        .init(category: .quirky, displayName: "Opening Microwave", fileName: "opening_microwave.wav"),
        .init(category: .quirky, displayName: "Timbre 1", fileName: "timbre1.wav"),
        .init(category: .percussion, displayName: "Metal Clank", fileName: "metal_clank.wav"),
        .init(category: .musical, displayName: "Synth Blip Bounce", fileName: "synth_blip_bounce.wav"),
        .init(category: .percussion, displayName: "Wood Clunk", fileName: "wood_clunk.wav")
    ]

    static let allSounds: [SoundOption] = timpaniSounds

    static func sounds(for category: SoundCategory) -> [SoundOption] {
        allSounds.filter { $0.category == category }
    }

    static func defaultSound(for widget: WidgetID) -> SoundOption {
        timpaniSounds[(widget.index - 1) % timpaniSounds.count]
    }
}
