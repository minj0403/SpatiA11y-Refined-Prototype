import Foundation

struct WidgetAudioSettings: Equatable {
    var pitch: Float = 1.0
    var volume: Float = 1.0
    var brightness: Float = 0.5
    var distanceGain: Float = 1.0
    var spread: Float = 0.5
    var isEnabled: Bool = true

    var selectedCategory: SoundCategory = .nature
    var selectedSoundName: String = "Rain"
}
