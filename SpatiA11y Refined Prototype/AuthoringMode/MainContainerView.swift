import SwiftUI

struct MainContainerView: View {
    @StateObject private var audioModel = AudioViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TopModeToggle(selectedScreen: $audioModel.selectedScreen)
                .padding()

            Group {
                switch audioModel.selectedScreen {
                case .authoring:
                    AuthoringModeView(audioModel: audioModel)
                case .controlCondition:
                    ControlConditionView(audioModel: audioModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            audioModel.startSystems()
        }
    }
}
