import Foundation
import SwiftUI
import Combine
import AVFoundation
import UIKit

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
    private let maxWidgets = 8
    private let widgetDiameter: CGFloat = 64

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
        syncHeadTracking()
    }

    func syncHeadTracking() {
        if globalSettings.headTrackingEnabled {
            startHeadTracking()
        } else {
            stopHeadTracking()
        }
    }

    func applyAllSettings() {
        spatialAudioManager.applyDynamicWidgets(authoredWidgets, global: globalSettings)
    }

    func createWidget(at position: CGPoint, canvasSize: CGSize) -> UUID? {
        guard authoredWidgets.count < maxWidgets else { return nil }

        let clampedPosition = clamped(position, in: canvasSize)
        guard canPlaceWidget(at: position, in: canvasSize, excludingID: nil) else { return nil }

        let soundIndex = authoredWidgets.count % AudioAssetLibrary.allSounds.count
        let sound = AudioAssetLibrary.allSounds[soundIndex]

        let widget = AuthoringWidget(
            id: UUID(),
            name: "Widget \(authoredWidgets.count + 1)",
            position: clampedPosition,
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

    func cancelWidgetCreation(id: UUID) {
        guard let index = authoredWidgets.firstIndex(where: { $0.id == id }) else { return }
        authoredWidgets.remove(at: index)
        if selectedWidgetID == id {
            selectedWidgetID = nil
        }
        PHASEManager.shared.removeDynamicWidget(id: id)
    }

    func selectWidget(id: UUID) {
        selectedWidgetID = id
    }

    func moveWidget(id: UUID, to position: CGPoint, canvasSize: CGSize) {
        guard let index = authoredWidgets.firstIndex(where: { $0.id == id }) else { return }

        let newPosition = clamped(position, in: canvasSize)
        guard canPlaceWidget(at: position, in: canvasSize, excludingID: id) else { return }

        authoredWidgets[index].position = newPosition

        PHASEManager.shared.addOrUpdateDynamicWidget(authoredWidgets[index], canvasSize: canvasSize)
    }

    func canPlaceWidget(
        at position: CGPoint,
        in canvasSize: CGSize,
        excludingID: UUID? = nil
    ) -> Bool {
        let clampedPosition = clamped(position, in: canvasSize)

        return !authoredWidgets.contains { widget in
            if widget.id == excludingID { return false }

            let dx = widget.position.x - clampedPosition.x
            let dy = widget.position.y - clampedPosition.y
            return sqrt(dx * dx + dy * dy) < widgetDiameter
        }
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
        speakAnnouncement(widget.name)
    }

    func announceWidgetCreatedNeedsName() {
        speakAnnouncement("Widget created. Name it.")
    }

    func announceWidgetCreationCancelled() {
        speakAnnouncement("Widget creation cancelled.")
    }

    func announceWidgetReadyForPlacement(name: String) {
        speakAnnouncement("\(name) created. Drag your finger to place it anywhere.")
    }

    func announceWidgetPlaced(name: String) {
        speakAnnouncement("\(name) placed.")
    }

    func announceWidgetReadyToMove(name: String) {
        speakAnnouncement("\(name) selected. Drag your finger to move it anywhere.")
    }

    private func speakAnnouncement(_ text: String) {
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: text)
            return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.mixWithOthers]
            )
            try session.setActive(true)
        } catch {
            print("speakWidgetName: audio session error \(error)")
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.volume = 1

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
