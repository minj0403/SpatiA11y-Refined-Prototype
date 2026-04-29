import Foundation

enum AuthoringCondition: String, CaseIterable, Identifiable {
    case directSpatial = "Direct Spatial"
    case gestureSequential = "Gesture Sequential"

    var id: String { rawValue }
}
