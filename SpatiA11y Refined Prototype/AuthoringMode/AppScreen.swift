import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case authoring = "Authoring"
    case controlCondition = "Control"

    var id: String { rawValue }
}
