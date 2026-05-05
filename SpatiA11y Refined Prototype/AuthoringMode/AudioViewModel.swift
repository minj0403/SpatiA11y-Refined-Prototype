import Foundation
import SwiftUI
import Combine
import AVFoundation

final class AudioViewModel: ObservableObject {
    @Published var selectedScreen: AppScreen = .authoring

    @Published var authoredWidgets: [AuthoringWidget] = []
    @Published var selectedWidgetID: UUID?

    @Published var globalSettings = GlobalAudioSettings()
    @Published var isFingerOnSurface = false
    @Published var isTTSActive = false

    let spatialAudioManager = SpatialAudioManager()
    let headTrackingManager = HeadTrackingManager()
    let ttsCoordinator = TTSCoordinator()

    private let speechSynth = AVSpeechSynthesizer()
    private let maxWidgets = 10

    init() {
        ttsCoordinator.onSpeechStateChanged = { [weak self] speaking in
            DispatchQueue.main.async {
                self?.isTTSActive = speaking
            }
        }
    }

    func startSystems() {
        spatialAudioManager.setupIfNeeded()
        applyAllSettings()
    }

    func applyAllSettings() {
        spatialAudioManager.applyDynamicWidgets(authoredWidgets, global: globalSettings)
    }

    func createWidget(at position: CGPoint, canvasSize: CGSize) -> UUID? {
        guard authoredWidgets.count < maxWidgets else { return nil }

        let soundIndex = authoredWidgets.count % AudioAssetLibrary.allSounds.count
        let sound = AudioAssetLibrary.allSounds[soundIndex]

        let widget = AuthoringWidget(
            id: UUID(),
            name: "Widget \(authoredWidgets.count + 1)",
            position: clamped(position, in: canvasSize),
            sound: sound
        )

        authoredWidgets.append(widget)
        selectedWidgetID = widget.id

        PHASEManager.shared.addOrUpdateDynamicWidget(widget, canvasSize: canvasSize)

        return widget.id
    }

    func renameWidget(id: UUID, name: String) {
        guard let index = authoredWidgets.firstIndex(where: { $0.id == id }) else { return }
        authoredWidgets[index].name = name
        PHASEManager.shared.addOrUpdateDynamicWidget(authoredWidgets[index], canvasSize: .zero)
    }

    func selectWidget(id: UUID) {
        selectedWidgetID = id
    }

    func moveWidget(id: UUID, to position: CGPoint, canvasSize: CGSize) {
        guard let index = authoredWidgets.firstIndex(where: { $0.id == id }) else { return }

        let newPosition = clamped(position, in: canvasSize)
        authoredWidgets[index].position = newPosition

        PHASEManager.shared.addOrUpdateDynamicWidget(authoredWidgets[index], canvasSize: canvasSize)
    }

    func widget(at point: CGPoint, radius: CGFloat) -> AuthoringWidget? {
        authoredWidgets.first { widget in
            let dx = widget.position.x - point.x
            let dy = widget.position.y - point.y
            return sqrt(dx * dx + dy * dy) <= radius
        }
    }

    func speakWidgetName(id: UUID) {
        guard let widget = authoredWidgets.first(where: { $0.id == id }) else { return }

        let utterance = AVSpeechUtterance(string: widget.name)
        utterance.rate = 0.5

        speechSynth.stopSpeaking(at: .immediate)
        speechSynth.speak(utterance)
    }

    func updateTouchState(_ touching: Bool) {
        isFingerOnSurface = touching
    }

    func handleTTSStateChange(_ speaking: Bool) {
        _ = speaking
    }

    func startHeadTracking() {
        headTrackingManager.start { [weak self] yaw, pitch, roll in
            guard let self else { return }
            guard self.globalSettings.headTrackingEnabled else { return }

            self.spatialAudioManager.updateListenerOrientation(
                yaw: yaw,
                pitch: pitch,
                roll: roll
            )
        }
    }

    func stopHeadTracking() {
        headTrackingManager.stop()
    }

    private func clamped(_ point: CGPoint, in size: CGSize) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return point }

        let padding: CGFloat = 44

        return CGPoint(
            x: min(max(point.x, padding), size.width - padding),
            y: min(max(point.y, padding), size.height - padding)
        )
    }
}
