import Foundation
import CoreGraphics

struct AuthoringWidget: Identifiable, Equatable {
    let id: UUID
    var name: String
    var position: CGPoint
    var sound: SoundOption
}
