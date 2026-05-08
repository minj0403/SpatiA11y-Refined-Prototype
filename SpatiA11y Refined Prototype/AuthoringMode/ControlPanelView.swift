import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var audioModel: AudioViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Widget Sound Controls")
                    .font(.title2)
                    .bold()

                ForEach(WidgetID.allCases) { widget in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(widget.rawValue)
                            .font(.headline)

                        Toggle("Enabled", isOn: Binding(
                            get: {
                                audioModel.widgetSettings[widget]?.isEnabled ?? true
                            },
                            set: { newValue in
                                audioModel.widgetSettings[widget]?.isEnabled = newValue
                                audioModel.applyAllSettings()
                            }
                        ))

                        VStack(alignment: .leading) {
                            Text("Volume")
                            Slider(value: Binding(
                                get: {
                                    Double(audioModel.widgetSettings[widget]?.volume ?? 1.0)
                                },
                                set: { newValue in
                                    audioModel.widgetSettings[widget]?.volume = Float(newValue)
                                    audioModel.applyAllSettings()
                                }
                            ), in: 0.0...1.0)
                        }

                        Picker("Sound", selection: Binding(
                            get: {
                                audioModel.widgetSettings[widget]?.selectedSoundName ?? "Bells"
                            },
                            set: { newValue in
                                audioModel.widgetSettings[widget]?.selectedSoundName = newValue

                                if let selected = AudioAssetLibrary.allSounds.first(where: { $0.displayName == newValue }) {
                                    audioModel.widgetSettings[widget]?.selectedCategory = selected.category
                                }

                                audioModel.applyAllSettings()
                            }
                        )) {
                            ForEach(AudioAssetLibrary.allSounds, id: \.displayName) { sound in
                                Text(sound.displayName).tag(sound.displayName)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
}
