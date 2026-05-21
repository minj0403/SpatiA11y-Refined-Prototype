import SwiftUI

struct GlobalControlSection: View {
    @ObservedObject var audioModel: AudioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overall Interface")
                .font(.headline)

            Toggle("Head Tracking", isOn: Binding(
                get: { audioModel.globalSettings.headTrackingEnabled },
                set: {
                    audioModel.globalSettings.headTrackingEnabled = $0
                    audioModel.syncHeadTracking()
                }
            ))

            Toggle("Only Play on Touch", isOn: Binding(
                get: { audioModel.globalSettings.playOnlyOnTouch },
                set: {
                    audioModel.globalSettings.playOnlyOnTouch = $0
                }
            ))

            Toggle("Duck During TTS", isOn: Binding(
                get: { audioModel.globalSettings.duckDuringTTS },
                set: {
                    audioModel.globalSettings.duckDuringTTS = $0
                }
            ))

            VStack(alignment: .leading) {
                Text("Room Reverb")
                Slider(value: Binding(
                    get: { Double(audioModel.globalSettings.roomReverb) },
                    set: {
                        audioModel.globalSettings.roomReverb = Float($0)
                    }
                ), in: 0.0...1.0)
            }

            VStack(alignment: .leading) {
                Text("Master Volume")
                Slider(value: Binding(
                    get: { Double(audioModel.globalSettings.masterVolume) },
                    set: {
                        audioModel.globalSettings.masterVolume = Float($0)
                    }
                ), in: 0.0...1.0)
            }

            Spacer()
        }
    }
}
