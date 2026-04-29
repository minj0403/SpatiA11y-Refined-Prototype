
import Foundation

struct SoundOption: Identifiable, Hashable {
    let id = UUID()
    let category: SoundCategory
    let displayName: String
    let fileName: String
}
