import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case authoring = "Spatial mode"
    case controlCondition = "Control"

    var id: String { rawValue }
}
