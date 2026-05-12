import Foundation
import AVFoundation
import PHASE
import simd
import AudioToolbox
import SwiftUI

final class PHASEManager {
    static let shared = PHASEManager()

    private var engine: PHASEEngine?
    private var listener: PHASEListener?
    private var widgetGrid: WidgetAudioGrid?

    private var isRunning = false
    private var motionTask: Task<Void, Never>?
    private var roomOccluders: [PHASEOccluder] = []

    private init() {}
    
    // updated 
    func addOrUpdateDynamicWidget(_ widget: AuthoringWidget, canvasSize: CGSize) {
        widgetGrid?.addOrUpdateDynamicWidget(widget, canvasSize: canvasSize)
    }

    func removeDynamicWidget(id: UUID) {
        widgetGrid?.removeDynamicWidget(id: id)
    }

    // MARK: - Authoring mode: silent widget placement

    func beginAuthoringWidget(_ widget: WidgetAudioGrid.WidgetID, at point: CGPoint, in size: CGSize) {
        widgetGrid?.beginAuthoringWidget(widget, at: point, in: size)
    }

    func updateAuthoringWidget(_ widget: WidgetAudioGrid.WidgetID, to point: CGPoint, in size: CGSize) {
        widgetGrid?.updateAuthoringWidget(widget, to: point, in: size)
    }

    func finishAuthoringWidget(_ widget: WidgetAudioGrid.WidgetID, at point: CGPoint, in size: CGSize) {
        widgetGrid?.finishAuthoringWidget(widget, at: point, in: size)
    }

    func clearAuthoredWidgets() {
        widgetGrid?.clearAuthoredWidgets()
    }

    // MARK: - Exploration mode: sound only while finger is down

    func fingerDown() {
        widgetGrid?.fingerDown()
    }

    func fingerUp() {
        widgetGrid?.fingerUp()
    }

    func updateFinger(_ p: CGPoint, in size: CGSize) {
        widgetGrid?.updateListenerFromScreenPoint(p, in: size)
    }

    func handleSingleTap() {
        widgetGrid?.handleSingleTapSpeakNearestIfInsideZone()
    }

    // MARK: - Lifecycle

    func start() throws {
        print("PHASEManager.start entered")

        if engine != nil { stop() }

        try configureAudioSession()

        let engine = PHASEEngine(updateMode: .automatic)
        self.engine = engine

        engine.outputSpatializationMode = .alwaysUseBinaural
        engine.defaultReverbPreset = .mediumRoom
        try engine.start()

        let listener = PHASEListener(engine: engine)
        try engine.rootObject.addChild(listener)
        self.listener = listener

        var t = matrix_identity_float4x4
        t.columns.3 = SIMD4<Float>(0, 0, -2.0, 1)
        listener.transform = t

        let room = WidgetAudioGrid.Room(
            width: 8.0,
            depth: 8.0,
            center: SIMD3<Float>(0, 0, -2.0),
            inset: 0.6,
            y: 0.0
        )

        let grid = WidgetAudioGrid(engine: engine, listener: listener, room: room)
        try grid.start()
        self.widgetGrid = grid

        print("PHASEManager.start complete, widgetGrid created")
    }

    func stop() {
        isRunning = false
        motionTask?.cancel()
        motionTask = nil

        widgetGrid?.stop()
        widgetGrid = nil

        roomOccluders.removeAll()
        engine?.stop()
        engine = nil
        listener = nil
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
    }

    // MARK: - Settings bridge

    func setRoomReverb(_ amount: Float) {
        widgetGrid?.setRoomReverb(amount)
    }

    func setMasterWidgetGain(_ gain: Float) {
        widgetGrid?.setMasterWidgetGain(gain)
    }

    func setWidgetEnabled(_ widget: WidgetAudioGrid.WidgetID, enabled: Bool) {
        widgetGrid?.setWidgetEnabled(widget, enabled: enabled)
    }

    func setWidgetPitch(_ widget: WidgetAudioGrid.WidgetID, pitch: Float) {
        widgetGrid?.setWidgetPitch(widget, pitch: pitch)
    }

    func setWidgetVolume(_ widget: WidgetAudioGrid.WidgetID, volume: Float) {
        widgetGrid?.setWidgetVolume(widget, volume: volume)
    }

    func setWidgetBrightness(_ widget: WidgetAudioGrid.WidgetID, brightness: Float) {
        widgetGrid?.setWidgetBrightness(widget, brightness: brightness)
    }

    func setWidgetDistanceGain(_ widget: WidgetAudioGrid.WidgetID, gain: Float) {
        widgetGrid?.setWidgetDistanceGain(widget, gain: gain)
    }

    func setWidgetSpread(_ widget: WidgetAudioGrid.WidgetID, spread: Float) {
        widgetGrid?.setWidgetSpread(widget, spread: spread)
    }

    func setWidgetSound(_ widget: WidgetAudioGrid.WidgetID, soundName: String) {
        widgetGrid?.setWidgetSound(widget, soundName: soundName)
    }

    func updateListenerOrientation(yaw: Float, pitch: Float, roll: Float) {
        widgetGrid?.updateListenerOrientation(yaw: yaw, pitch: pitch, roll: roll)
    }
}
