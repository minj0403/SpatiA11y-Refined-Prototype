import Foundation
import PHASE
import simd
import AVFoundation
import SwiftUI

final class WidgetAudioGrid {

    enum WidgetID: CaseIterable {
        case widget1, widget2, widget3, widget4, widget5
        case widget6, widget7, widget8, widget9, widget10

        var spokenName: String {
            switch self {
            case .widget1: return "Widget 1"
            case .widget2: return "Widget 2"
            case .widget3: return "Widget 3"
            case .widget4: return "Widget 4"
            case .widget5: return "Widget 5"
            case .widget6: return "Widget 6"
            case .widget7: return "Widget 7"
            case .widget8: return "Widget 8"
            case .widget9: return "Widget 9"
            case .widget10: return "Widget 10"
            }
        }

        var defaultSoundOption: SoundOption {
            let sounds = AudioAssetLibrary.allSounds
            let index = stableIndex % sounds.count
            return sounds[index]
        }

        var stableIndex: Int {
            switch self {
            case .widget1: return 0
            case .widget2: return 1
            case .widget3: return 2
            case .widget4: return 3
            case .widget5: return 4
            case .widget6: return 5
            case .widget7: return 6
            case .widget8: return 7
            case .widget9: return 8
            case .widget10: return 9
            }
        }
    }

    struct Room {
        var width: Float
        var depth: Float
        var center: SIMD3<Float>
        var inset: Float = 0.6
        var y: Float = 0.0
    }

    private let engine: PHASEEngine
    private let listener: PHASEListener
    private let room: Room

    private var sources: [WidgetID: PHASESource] = [:]
    private var events: [WidgetID: PHASESoundEvent] = [:]
    private var authoredPositions: [WidgetID: SIMD3<Float>] = [:]
    private var listenerPosWorld: SIMD3<Float> = .zero

    private let activationRadius: Float = 0.5
    private let speechSynth = AVSpeechSynthesizer()
    private var explorationTouchIsDown = false
    private var masterGain: Float = 1.0
    
    private var dynamicSources: [UUID: PHASESource] = [:]
    private var dynamicEvents: [UUID: PHASESoundEvent] = [:]
    private var dynamicWidgets: [UUID: AuthoringWidget] = [:]
    private var latestCanvasSize: CGSize = .zero
    
    private var touchIsDown = false

    private struct RuntimeConfig {
        var isEnabled: Bool = true
        var selectedSoundBaseName: String
        var volume: Float = 1.0
    }

    private var runtimeConfig: [WidgetID: RuntimeConfig] = Dictionary(
        uniqueKeysWithValues: WidgetID.allCases.map { widget in
            let baseName = widget.defaultSoundOption.fileName.replacingOccurrences(of: ".wav", with: "")
            return (widget, RuntimeConfig(selectedSoundBaseName: baseName))
        }
    )

    init(engine: PHASEEngine, listener: PHASEListener, room: Room) {
        self.engine = engine
        self.listener = listener
        self.room = room
    }

    private func stableName(for widget: WidgetID) -> String { "widget\(widget.stableIndex + 1)" }
    private func mixerID(for widget: WidgetID) -> String { "\(stableName(for: widget))_mixer" }
    private func assetID(for widget: WidgetID) -> String { "\(stableName(for: widget))_asset" }
    private func eventID(for widget: WidgetID) -> String { "\(stableName(for: widget))_event" }

    // MARK: - Lifecycle

    func start() throws {
        print("WidgetAudioGrid.start entered")

        // Register all 10 default assets now, but do NOT play them.
        // Authoring mode only places silent sources.
        for widget in WidgetID.allCases {
            let src = PHASESource(engine: engine)
            try engine.rootObject.addChild(src)
            sources[widget] = src
            setTransform(src, position: room.center)

            let baseName = runtimeConfig[widget]?.selectedSoundBaseName
                ?? widget.defaultSoundOption.fileName.replacingOccurrences(of: ".wav", with: "")
            try registerAssets(soundName: baseName, for: widget)
        }

        setTransform(listener, position: room.center)
        listenerPosWorld = room.center
        print("WidgetAudioGrid.start completed — all widgets silent until exploration fingerDown")
    }
    
    func stop() {
        for (_, evt) in events {
            evt.stopAndInvalidate()
        }

        for (_, evt) in dynamicEvents {
            evt.stopAndInvalidate()
        }

        events.removeAll()
        dynamicEvents.removeAll()
        sources.removeAll()
        dynamicSources.removeAll()
        dynamicWidgets.removeAll()
        touchIsDown = false
    }

    // MARK: - Authoring mode: silent placement

    func beginAuthoringWidget(_ widget: WidgetID, at point: CGPoint, in size: CGSize) {
        guard authoredPositions[widget] == nil else { return }
        let pos = worldPosition(from: point, in: size)
        authoredPositions[widget] = pos
        setTransform(sources[widget], position: pos)
        // No sound starts here.
    }

    func updateAuthoringWidget(_ widget: WidgetID, to point: CGPoint, in size: CGSize) {
        guard authoredPositions[widget] != nil else { return }
        let pos = worldPosition(from: point, in: size)
        authoredPositions[widget] = pos
        setTransform(sources[widget], position: pos)
        // Still silent while dragging.
    }

    func finishAuthoringWidget(_ widget: WidgetID, at point: CGPoint, in size: CGSize) {
        let pos = worldPosition(from: point, in: size)
        authoredPositions[widget] = pos
        setTransform(sources[widget], position: pos)
        // Still silent after placement.
    }

    func clearAuthoredWidgets() {
        stopAllEvents()
        authoredPositions.removeAll()
        for source in sources.values {
            setTransform(source, position: room.center)
        }
    }

    // MARK: - Exploration mode: sound only plays while exploring

    func fingerDown() {
        guard !touchIsDown else { return }
        touchIsDown = true
        print("fingerDown")

        for widget in WidgetID.allCases {
            guard runtimeConfig[widget]?.isEnabled == true else { continue }
            spawnAndStart(widget)
        }

        for widget in dynamicWidgets.values {
            spawnAndStartDynamicWidget(widget)
        }
    }

    func fingerUp() {
        guard touchIsDown else { return }
        touchIsDown = false
        print("fingerUp")

        for (_, evt) in events {
            evt.stopAndInvalidate()
        }
        events.removeAll()

        for (_, evt) in dynamicEvents {
            evt.stopAndInvalidate()
        }
        dynamicEvents.removeAll()
    }

    private func stopAllEvents() {
        for (_, evt) in events { evt.stopAndInvalidate() }
        events.removeAll()
    }

    private func spawnAndStart(_ widget: WidgetID) {
        guard let src = sources[widget] else { return }
        guard authoredPositions[widget] != nil else { return }

        if let old = events[widget] {
            old.stopAndInvalidate()
            events[widget] = nil
        }

        let widgetVolume = runtimeConfig[widget]?.volume ?? 1.0
        src.gain = Double(widgetVolume * masterGain)

        let params = PHASEMixerParameters()
        params.addSpatialMixerParameters(
            identifier: mixerID(for: widget),
            source: src,
            listener: listener
        )

        do {
            let evt = try PHASESoundEvent(
                engine: engine,
                assetIdentifier: eventID(for: widget),
                mixerParameters: params
            )
            evt.start()
            events[widget] = evt
        } catch {
            print("spawnAndStart FAILED for \(widget):", error)
        }
    }

    // MARK: - Asset Registration

    private func registerAssets(soundName: String, for widget: WidgetID) throws {
        try registerBundledSoundAsset(name: soundName, ext: "wav", assetID: assetID(for: widget))
        try registerLoopingSoundEvent(
            eventID: eventID(for: widget),
            soundAssetID: assetID(for: widget),
            mixerID: mixerID(for: widget)
        )
    }

    private func unregisterAssets(for widget: WidgetID, completion: @escaping () -> Void) {
        engine.assetRegistry.unregisterAsset(identifier: eventID(for: widget)) { _ in
            self.engine.assetRegistry.unregisterAsset(identifier: self.assetID(for: widget)) { _ in
                DispatchQueue.main.async { completion() }
            }
        }
    }

    private func registerBundledSoundAsset(name: String, ext: String, assetID: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw NSError(domain: "WidgetAudioGrid", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing \(name).\(ext)"])
        }

        let monoLayout = AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Mono)!
        _ = try engine.assetRegistry.registerSoundAsset(
            url: url,
            identifier: assetID,
            assetType: .streamed,
            channelLayout: monoLayout,
            normalizationMode: .none
        )
    }

    private func registerLoopingSoundEvent(eventID: String,
                                           soundAssetID: String,
                                           mixerID: String) throws {
        guard let pipeline = PHASESpatialPipeline(flags: [.directPathTransmission, .lateReverb]) else {
            throw NSError(domain: "WidgetAudioGrid", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to create PHASESpatialPipeline"])
        }

        pipeline.entries[PHASESpatialCategory.earlyReflections]?.sendLevel = 0.06
        pipeline.entries[.lateReverb]?.sendLevel = 0.05

        let mixer = PHASESpatialMixerDefinition(spatialPipeline: pipeline, identifier: mixerID)
        let distance = PHASEGeometricSpreadingDistanceModelParameters()
        distance.rolloffFactor = 1.2
        mixer.distanceModelParameters = distance

        let sampler = PHASESamplerNodeDefinition(
            soundAssetIdentifier: soundAssetID,
            mixerDefinition: mixer
        )
        sampler.playbackMode = .looping

        _ = try engine.assetRegistry.registerSoundEventAsset(rootNode: sampler, identifier: eventID)
    }

    // MARK: - Public Controls

    func setWidgetEnabled(_ widget: WidgetID, enabled: Bool) {
        guard var config = runtimeConfig[widget] else { return }
        config.isEnabled = enabled
        runtimeConfig[widget] = config

        if !enabled {
            events[widget]?.stopAndInvalidate()
            events[widget] = nil
        } else if explorationTouchIsDown {
            spawnAndStart(widget)
        }
    }

    func setWidgetVolume(_ widget: WidgetID, volume: Float) {
        guard var config = runtimeConfig[widget] else { return }
        config.volume = volume
        runtimeConfig[widget] = config
        sources[widget]?.gain = Double(volume * masterGain)
    }

    func setWidgetSound(_ widget: WidgetID, soundName: String) {
        guard var config = runtimeConfig[widget] else { return }
        let newBaseName = fileBaseName(from: soundName)
        guard config.selectedSoundBaseName != newBaseName else { return }

        config.selectedSoundBaseName = newBaseName
        runtimeConfig[widget] = config

        events[widget]?.stopAndInvalidate()
        events[widget] = nil

        unregisterAssets(for: widget) {
            do {
                try self.registerAssets(soundName: newBaseName, for: widget)
                if self.explorationTouchIsDown && config.isEnabled {
                    self.spawnAndStart(widget)
                }
            } catch {
                print("Failed to swap sound for \(widget):", error)
            }
        }
    }

    func setWidgetPitch(_ widget: WidgetID, pitch: Float) {}
    func setWidgetBrightness(_ widget: WidgetID, brightness: Float) {}
    func setWidgetDistanceGain(_ widget: WidgetID, gain: Float) {}
    func setWidgetSpread(_ widget: WidgetID, spread: Float) {}
    func setRoomReverb(_ amount: Float) {}

    func setMasterWidgetGain(_ gain: Float) {
        masterGain = gain
        for widget in WidgetID.allCases {
            let widgetVolume = runtimeConfig[widget]?.volume ?? 1.0
            sources[widget]?.gain = Double(widgetVolume * masterGain)
        }
    }

    // MARK: - Listener / exploration finger position

    func updateListenerFromScreenPoint(_ p: CGPoint, in size: CGSize) {
        let pos = worldPosition(from: p, in: size)
        setTransform(listener, position: pos)
        listenerPosWorld = pos
    }

    func updateListenerOrientation(yaw: Float, pitch: Float, roll: Float) {
        var t = matrix_identity_float4x4
        t.columns.3 = SIMD4<Float>(listenerPosWorld.x, listenerPosWorld.y, listenerPosWorld.z, 1)
        let c = cos(yaw), s = sin(yaw)
        t.columns.0 = SIMD4<Float>( c, 0, s, 0)
        t.columns.2 = SIMD4<Float>(-s, 0, c, 0)
        listener.transform = t
    }

    // MARK: - TTS

    func handleSingleTapSpeakNearestIfInsideZone() {
        guard let widget = nearestWidgetInsideActivationZone() else { return }
        let utterance = AVSpeechUtterance(string: widget.spokenName)
        utterance.rate = 0.5
        speechSynth.stopSpeaking(at: .immediate)
        speechSynth.speak(utterance)
    }
    
    // additional helpers
    func addOrUpdateDynamicWidget(_ widget: AuthoringWidget, canvasSize: CGSize) {
        if canvasSize.width > 0, canvasSize.height > 0 {
            latestCanvasSize = canvasSize
        }

        dynamicWidgets[widget.id] = widget

        do {
            let source: PHASESource

            if let existingSource = dynamicSources[widget.id] {
                source = existingSource
            } else {
                let newSource = PHASESource(engine: engine)
                try engine.rootObject.addChild(newSource)
                dynamicSources[widget.id] = newSource

                try registerDynamicAssets(for: widget)
                source = newSource
            }

            let worldPosition = worldPositionFromScreenPoint(widget.position, canvasSize: latestCanvasSize)
            setTransform(source, position: worldPosition)

            if touchIsDown {
                spawnAndStartDynamicWidget(widget)
            }
        } catch {
            print("Failed to add/update dynamic widget:", error)
        }
    }
    
    private func dynamicAssetID(for id: UUID) -> String {
        "dynamic_\(id.uuidString)_asset"
    }

    private func dynamicEventID(for id: UUID) -> String {
        "dynamic_\(id.uuidString)_event"
    }

    private func dynamicMixerID(for id: UUID) -> String {
        "dynamic_\(id.uuidString)_mixer"
    }

    private func registerDynamicAssets(for widget: AuthoringWidget) throws {
        let baseName = widget.sound.fileName.replacingOccurrences(of: ".wav", with: "")

        try registerBundledSoundAsset(
            name: baseName,
            ext: "wav",
            assetID: dynamicAssetID(for: widget.id)
        )

        try registerLoopingSoundEvent(
            eventID: dynamicEventID(for: widget.id),
            soundAssetID: dynamicAssetID(for: widget.id),
            mixerID: dynamicMixerID(for: widget.id)
        )
    }

    private func spawnAndStartDynamicWidget(_ widget: AuthoringWidget) {
        guard let source = dynamicSources[widget.id] else { return }

        if let old = dynamicEvents[widget.id] {
            old.stopAndInvalidate()
            dynamicEvents[widget.id] = nil
        }

        let params = PHASEMixerParameters()
        params.addSpatialMixerParameters(
            identifier: dynamicMixerID(for: widget.id),
            source: source,
            listener: listener
        )

        do {
            let event = try PHASESoundEvent(
                engine: engine,
                assetIdentifier: dynamicEventID(for: widget.id),
                mixerParameters: params
            )

            event.start()
            dynamicEvents[widget.id] = event
        } catch {
            print("Failed to start dynamic widget:", error)
        }
    }

    private func worldPositionFromScreenPoint(_ point: CGPoint, canvasSize: CGSize) -> SIMD3<Float> {
        guard canvasSize.width > 0, canvasSize.height > 0 else {
            return SIMD3<Float>(room.center.x, room.y, room.center.z)
        }

        let nx = Float((point.x / canvasSize.width) * 2 - 1)
        let ny = Float((point.y / canvasSize.height) * 2 - 1)

        let x = room.center.x + nx * (room.width * 0.5 - room.inset)
        let z = room.center.z + ny * (room.depth * 0.5 - room.inset)

        return SIMD3<Float>(x, room.y, z)
    }

    // MARK: - Helpers

    private func worldPosition(from point: CGPoint, in size: CGSize) -> SIMD3<Float> {
        guard size.width > 0, size.height > 0 else { return room.center }

        let nx = Float((point.x / size.width) * 2 - 1)
        let ny = Float((point.y / size.height) * 2 - 1)

        let x = room.center.x + nx * (room.width * 0.5 - room.inset)
        let z = room.center.z + ny * (room.depth * 0.5 - room.inset)

        return SIMD3<Float>(x, room.y, z)
    }

    private func setTransform(_ obj: PHASEObject?, position: SIMD3<Float>) {
        guard let obj else { return }
        var t = matrix_identity_float4x4
        t.columns.3 = SIMD4<Float>(position.x, position.y, position.z, 1)
        obj.transform = t
    }

    private func nearestWidgetInsideActivationZone() -> WidgetID? {
        var best: WidgetID?
        var bestDist = Float.greatestFiniteMagnitude

        for (widget, pos) in authoredPositions {
            let d = simd_distance(listenerPosWorld, pos)
            if d <= activationRadius && d < bestDist {
                bestDist = d
                best = widget
            }
        }

        return best
    }

    private func fileBaseName(from displayName: String) -> String {
        if let option = AudioAssetLibrary.allSounds.first(where: { $0.displayName == displayName }) {
            return option.fileName.replacingOccurrences(of: ".wav", with: "")
        }
        return displayName.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
