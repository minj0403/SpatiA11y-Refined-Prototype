import Foundation

enum AudioAssetLibrary {
    static let timpaniSounds: [SoundOption] = [
        .init(category: .percussion, displayName: "Timpani 1", fileName: "timpani1.wav"),
        .init(category: .percussion, displayName: "Timpani 2", fileName: "timpani2.wav"),
        .init(category: .percussion, displayName: "Timpani 3", fileName: "timpani3.wav"),
        .init(category: .percussion, displayName: "Timpani 4", fileName: "timpani4.wav"),
        .init(category: .percussion, displayName: "Timpani 5", fileName: "timpani5.wav"),
        .init(category: .percussion, displayName: "Timpani 6", fileName: "timpani6.wav"),
        .init(category: .percussion, displayName: "Timpani 7", fileName: "timpani7.wav"),
        .init(category: .percussion, displayName: "Timpani 8 Repeated", fileName: "timpani8.wav"),
        .init(category: .percussion, displayName: "Timpani 9 Repeated", fileName: "timpani9.wav"),
        .init(category: .percussion, displayName: "Timpani 10 Triple", fileName: "timpani10.wav")
    ]

    static let allSounds: [SoundOption] = timpaniSounds + [
        .init(category: .nature, displayName: "Rain", fileName: "rain.wav"),
        .init(category: .nature, displayName: "Creek", fileName: "creek.wav"),
        .init(category: .nature, displayName: "Birds", fileName: "birds.wav"),
        .init(category: .nature, displayName: "Cricket 1", fileName: "cricket1.wav"),
        .init(category: .nature, displayName: "Cricket 2", fileName: "cricket2.wav"),
        .init(category: .pads, displayName: "Moss 1", fileName: "moss1.wav"),
        .init(category: .pads, displayName: "Moss 2", fileName: "moss2.wav"),
        .init(category: .pads, displayName: "Bright Pad", fileName: "brightpad.wav"),
        .init(category: .pads, displayName: "Sub Pad", fileName: "subpad.wav"),
        .init(category: .musical, displayName: "Kalimba Fall", fileName: "kalimba.wav"),
        .init(category: .musical, displayName: "Tongue Drum", fileName: "tonguedrum.wav"),
        .init(category: .quirky, displayName: "Sheep", fileName: "sheep.wav")
    ]

    static func sounds(for category: SoundCategory) -> [SoundOption] {
        allSounds.filter { $0.category == category }
    }

    static func defaultSound(for widget: WidgetID) -> SoundOption {
        timpaniSounds[(widget.index - 1) % timpaniSounds.count]
    }
}
