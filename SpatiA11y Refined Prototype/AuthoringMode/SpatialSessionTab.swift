import Foundation

enum SpatialSessionTab: String, CaseIterable, Identifiable {
    case authoring = "Authoring"
    case retrievalTesting = "Retrieval"

    var id: String { rawValue }
}
