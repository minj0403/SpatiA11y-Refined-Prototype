import SwiftUI

struct AudioSettingsView: View {
    @ObservedObject var audioModel: AudioViewModel

    var body: some View {
        HStack(spacing: 0) {
            GlobalControlSection(audioModel: audioModel)
                .frame(width: 320)
                .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                Text("Study Notes")
                    .font(.headline)

                Text("This screen now only manages global settings. Item-specific settings are edited in Author mode after selecting an item.")
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
