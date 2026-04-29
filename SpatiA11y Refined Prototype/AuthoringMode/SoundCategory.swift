import Foundation

enum SoundCategory: String, CaseIterable, Identifiable {
    case percussion = "Percussion"
    case nature = "Nature"
    case pads = "Pads"
    case musical = "Musical"
    case quirky = "Quirky"

    var id: String { rawValue }
}
