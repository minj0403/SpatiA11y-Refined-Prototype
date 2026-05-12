import Foundation

enum SpatialAuthoringPhase: Equatable {
    case exploring
    case naming(widgetID: UUID, awaitingRetry: Bool)
    case dictating(widgetID: UUID)
    case confirming(widgetID: UUID, name: String)
    case placing(widgetID: UUID)
    case moving(widgetID: UUID)

    var statusTitle: String {
        switch self {
        case .exploring:
            return "Exploring"
        case .naming:
            return "Naming"
        case .dictating:
            return "Dictating"
        case .confirming:
            return "Confirming"
        case .placing:
            return "Placing"
        case .moving:
            return "Moving"
        }
    }

    var allowsSpatialExploration: Bool {
        switch self {
        case .exploring:
            return true
        case .naming, .dictating, .confirming, .placing, .moving:
            return false
        }
    }
}
