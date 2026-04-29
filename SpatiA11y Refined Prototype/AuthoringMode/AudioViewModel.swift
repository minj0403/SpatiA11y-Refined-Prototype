import Foundation
import SwiftUI
import Combine

final class AudioViewModel: ObservableObject {
    @Published var selectedScreen: AppScreen = .authoring

    @Published var widgetSettings: [WidgetID: WidgetAudioSettings] = Dictionary(
        uniqueKeysWithValues: WidgetID.allCases.map { widget in
            let defaults = AudioViewModel.defaultSound(for: widget)
            return (widget, WidgetAudioSettings(
                pitch: 1.0,
                volume: 1.0,
                brightness: 0.5,
                distanceGain: 1.0,
                spread: 0.0,
                isEnabled: true,
                selectedCategory: defaults.category,
                selectedSoundName: defaults.displayName
            ))
        }
    )

    @Published var globalSettings = GlobalAudioSettings()
    @Published var isFingerOnSurface = false
    @Published var isTTSActive = false

    // Authoring state for the visual canvas.
    @Published var placedWidgetPositions: [WidgetID: CGPoint] = [:]
    @Published var previewWidget: WidgetID? = nil
    @Published var previewPosition: CGPoint? = nil

    let maxAuthorableWidgets = 10

    let spatialAudioManager = SpatialAudioManager()
    let headTrackingManager = HeadTrackingManager()
    let ttsCoordinator = TTSCoordinator()

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
        spatialAudioManager.apply(widgetSettings: widgetSettings, global: globalSettings)
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

    // MARK: - Authoring

    var nextWidgetToPlace: WidgetID? {
        WidgetID.allCases.first { placedWidgetPositions[$0] == nil }
    }

    func beginAuthoringPreview(at point: CGPoint) -> WidgetID? {
        guard placedWidgetPositions.count < maxAuthorableWidgets,
              let next = nextWidgetToPlace else {
            previewWidget = nil
            previewPosition = nil
            return nil
        }

        previewWidget = next
        previewPosition = point
        return next
    }

    func updateAuthoringPreview(to point: CGPoint) {
        guard previewWidget != nil else { return }
        previewPosition = point
    }

    func commitAuthoringPreview(at point: CGPoint) -> WidgetID? {
        guard let widget = previewWidget else { return nil }
        placedWidgetPositions[widget] = point
        previewWidget = nil
        previewPosition = nil
        return widget
    }

    func clearAuthoredLayout() {
        placedWidgetPositions.removeAll()
        previewWidget = nil
        previewPosition = nil
        PHASEManager.shared.clearAuthoredWidgets()
    }

    private static func defaultSound(for widget: WidgetID) -> SoundOption {
        let sounds = AudioAssetLibrary.allSounds
        let index = (widget.index - 1) % sounds.count
        return sounds[index]
    }
}
