import Foundation
import simd
import CoreGraphics

final class SpatialAudioManager {
    private var isSetup = false
    private var isStarting = false

    func setupIfNeeded() {
        print("setupIfNeeded called, isSetup =", isSetup, "isStarting =", isStarting)

        guard !isSetup, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }

        do {
            try PHASEManager.shared.start()
            isSetup = true
            print("SpatialAudioManager setup succeeded")
        } catch {
            isSetup = false
            print("Failed to start PHASEManager:", error)
        }
    }

    func apply(widgetSettings: [WidgetID: WidgetAudioSettings],
               global: GlobalAudioSettings) {
        PHASEManager.shared.setRoomReverb(global.roomReverb)
        PHASEManager.shared.setMasterWidgetGain(global.masterVolume)

        for (widgetID, settings) in widgetSettings {
            PHASEManager.shared.setWidgetEnabled(map(widgetID), enabled: settings.isEnabled)
            PHASEManager.shared.setWidgetPitch(map(widgetID), pitch: settings.pitch)
            PHASEManager.shared.setWidgetVolume(map(widgetID), volume: settings.volume)
            PHASEManager.shared.setWidgetBrightness(map(widgetID), brightness: settings.brightness)
            PHASEManager.shared.setWidgetDistanceGain(map(widgetID), gain: settings.distanceGain)
            PHASEManager.shared.setWidgetSpread(map(widgetID), spread: settings.spread)
            PHASEManager.shared.setWidgetSound(map(widgetID), soundName: settings.selectedSoundName)
        }
    }
    
    func applyDynamicWidgets(_ widgets: [AuthoringWidget], global: GlobalAudioSettings) {
        PHASEManager.shared.setRoomReverb(global.roomReverb)

        for widget in widgets {
            PHASEManager.shared.addOrUpdateDynamicWidget(widget, canvasSize: .zero)
        }
    }

    func updateListenerOrientation(yaw: Float, pitch: Float, roll: Float) {
        PHASEManager.shared.updateListenerOrientation(yaw: yaw, pitch: pitch, roll: roll)
    }

    func fadeAllWidgets(to value: Float, duration: TimeInterval) {
        _ = value
        _ = duration
    }

    private func map(_ widgetID: WidgetID) -> WidgetAudioGrid.WidgetID {
        switch widgetID {
        case .widget1: return .widget1
        case .widget2: return .widget2
        case .widget3: return .widget3
        case .widget4: return .widget4
        case .widget5: return .widget5
        case .widget6: return .widget6
        case .widget7: return .widget7
        case .widget8: return .widget8
        case .widget9: return .widget9
        case .widget10: return .widget10
        }
    }
}
