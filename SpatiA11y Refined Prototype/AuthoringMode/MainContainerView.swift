import SwiftUI

struct MainContainerView: View {
    @StateObject private var audioModel = AudioViewModel()

    var body: some View {
        AuthoringModeView(audioModel: audioModel)
            .onAppear {
                audioModel.startSystems()
            }
    }
}
