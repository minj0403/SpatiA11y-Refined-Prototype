import SwiftUI

struct MainContainerView: View {
    @StateObject private var audioModel = AudioViewModel()
    @State private var spatialSessionTab: SpatialSessionTab = .authoring

    var body: some View {
        VStack(spacing: 0) {
            TopModeToggle(selectedScreen: $audioModel.selectedScreen)
                .padding()

            Group {
                switch audioModel.selectedScreen {
                case .authoring:
                    VStack(spacing: 0) {
                        Picker("Spatial session", selection: $spatialSessionTab) {
                            ForEach(SpatialSessionTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding([.horizontal, .bottom])

                        switch spatialSessionTab {
                        case .authoring:
                            AuthoringModeView(audioModel: audioModel)
                        case .retrievalTesting:
                            RetrievalTestingView(audioModel: audioModel)
                        }
                    }
                case .controlCondition:
                    ControlConditionView(audioModel: audioModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            audioModel.startSystems()
        }
        .onChange(of: audioModel.selectedScreen) { screen in
            if screen != .authoring {
                spatialSessionTab = .authoring
            }
        }
    }
}
