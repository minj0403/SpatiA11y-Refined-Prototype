import Foundation

enum AppScreen: String, CaseIterable, Identifiable {
    case authoring = "Authoring"
    case exploration = "Exploration"
    case controlCondition = "Control Condition"
    case controlPanel = "Control Panel"

    var id: String { rawValue }
}
