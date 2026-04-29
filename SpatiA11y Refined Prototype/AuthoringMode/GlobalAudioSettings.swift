import Foundation

struct GlobalAudioSettings: Equatable {
    var roomReverb: Float = 0.2
    var masterVolume: Float = 1.0
    var headTrackingEnabled: Bool = true
    var playOnlyOnTouch: Bool = true
    var duckDuringTTS: Bool = true
}
