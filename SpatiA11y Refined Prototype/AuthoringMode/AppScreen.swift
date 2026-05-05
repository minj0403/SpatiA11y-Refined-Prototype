import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case authoring = "Authoring Mode"

    var id: String { rawValue }
}
