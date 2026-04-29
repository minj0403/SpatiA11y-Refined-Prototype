import Foundation

final class TTSCoordinator {
    var onSpeechStateChanged: ((Bool) -> Void)?

    func speechDidStart() {
        onSpeechStateChanged?(true)
    }

    func speechDidFinish() {
        onSpeechStateChanged?(false)
    }
}
