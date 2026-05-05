import SwiftUI

struct TopModeToggle: View {
    @Binding var selectedScreen: AppScreen

    var body: some View {
        Picker("Study condition", selection: $selectedScreen) {
            ForEach(AppScreen.allCases) { screen in
                Text(screen.rawValue).tag(screen)
            }
        }
        .pickerStyle(.segmented)
    }
}
