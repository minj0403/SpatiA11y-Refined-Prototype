import SwiftUI

struct AuthoringModeView: View {
    @ObservedObject var audioModel: AudioViewModel
    @State private var speechGuide = SpatialSpeechGuide()

    @State private var phase: SpatialAuthoringPhase = .exploring
    @State private var isExploring = false
    @State private var touchBeganAt: Date?
    @State private var didStartDictationForTouch = false
    @State private var lastCanvasTapTime: Date = .distantPast
    @State private var lastCanvasTapPoint: CGPoint = .zero
    @State private var hasSpokenOrientation = false
    @State private var holdTimer: Timer?
    @State private var pendingConfirmation: DispatchWorkItem?

    private let widgetDiameter: CGFloat = 64
    private let tapMoveThreshold: CGFloat = 12
    private let holdThreshold: TimeInterval = 0.3
    private let doubleTapThreshold: TimeInterval = 0.4
    private let doubleTapDistance: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ForEach(audioModel.authoredWidgets) { widget in
                    widgetView(widget)
                        .position(widget.position)
                        .allowsHitTesting(false)
                }

                VStack {
                    Text("Spatial mode")
                        .font(.title2)
                        .bold()

                    Text(statusDetail)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Spacer()

                    Text("\(audioModel.authoredWidgets.count)/8 widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom)
                }
                .padding()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                SpatialExplorationTouchSurface(
                    onTouchBegan: { location in
                        handleTouchBegan(at: location)
                    },
                    onTouchChanged: { location in
                        handleTouchChanged(at: location, canvasSize: geo.size)
                    },
                    onTouchEnded: { location, start in
                        handleTouchEnded(at: location, start: start, canvasSize: geo.size)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .accessibilityHidden(true)
            .onAppear {
                speechGuide.preparePermissions { _ in }
                speakOrientationIfNeeded()
            }
            .onDisappear {
                cancelHoldTimer()
                cancelPendingConfirmation()
                endExplorationIfNeeded()
                speechGuide.stopDictation()
            }
        }
    }

    private var statusDetail: String {
        switch phase {
        case .exploring:
            return "Exploring. Tap empty space to create a widget. Double tap a widget to move it."
        case .naming(_, let awaitingRetry):
            if awaitingRetry {
                return "Naming. Hold to dictate again. Double tap to cancel."
            }
            return "Naming. Hold to dictate a name. Double tap to cancel."
        case .dictating:
            return "Dictating. Release when finished."
        case .confirming(_, let name):
            return "Confirming \(name). Tap once to place. Double tap to cancel."
        case .placing:
            return "Placing. Drag to position, then lift to set."
        case .moving:
            return "Moving. Drag to reposition, then lift to set. Double tap to cancel."
        }
    }

    private func widgetView(_ widget: AuthoringWidget) -> some View {
        let isSelected = audioModel.selectedWidgetID == widget.id

        return ZStack {
            Circle()
                .fill(isSelected ? Color.blue.opacity(0.25) : Color.gray.opacity(0.2))
                .frame(width: widgetDiameter, height: widgetDiameter)

            Circle()
                .stroke(isSelected ? Color.blue : Color.gray, lineWidth: isSelected ? 4 : 2)
                .frame(width: widgetDiameter, height: widgetDiameter)

            VStack(spacing: 4) {
                Image(systemName: "circle.grid.cross")
                    .font(.title3)

                Text(widget.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
    }

    private func speakOrientationIfNeeded() {
        guard !hasSpokenOrientation else { return }
        hasSpokenOrientation = true
        speechGuide.speak(
            "Spatial mode. Drag to hear nearby widgets. Top of the screen is in front, bottom is behind. On a widget, you will hear its name. Tap empty space to create a widget. Double tap a widget to move it. Eight widgets maximum."
        )
    }

    private func speakNamingPrompt(awaitingRetry: Bool) {
        if awaitingRetry {
            speechGuide.speak("I didn't catch that. Hold to dictate again. Double tap to cancel.")
        } else {
            speechGuide.speak("Widget created. Tap and hold to dictate a name. Double tap to cancel.")
        }
    }

    private func beginExplorationIfNeeded() {
        guard !isExploring else { return }
        isExploring = true
        PHASEManager.shared.fingerDown()
    }

    private func endExplorationIfNeeded() {
        guard isExploring else { return }
        isExploring = false
        PHASEManager.shared.setExcludedDynamicWidget(nil)
        PHASEManager.shared.fingerUp()
    }

    private func handleTouchBegan(at location: CGPoint) {
        touchBeganAt = Date()
        didStartDictationForTouch = false
        cancelHoldTimer()

        switch phase {
        case .placing(let widgetID), .moving(let widgetID):
            PHASEManager.shared.setExcludedDynamicWidget(widgetID)
            beginExplorationIfNeeded()
        case .naming(let widgetID, _):
            scheduleHoldTimer(for: widgetID)
        default:
            break
        }
    }

    private func scheduleHoldTimer(for widgetID: UUID) {
        cancelHoldTimer()
        let timer = Timer(timeInterval: holdThreshold, repeats: false) { _ in
            startDictation(for: widgetID)
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
    }

    private func cancelPendingConfirmation() {
        pendingConfirmation?.cancel()
        pendingConfirmation = nil
    }

    private func resetTapTracking() {
        lastCanvasTapTime = .distantPast
        lastCanvasTapPoint = .zero
    }

    private func transitionToExploring(announcement: String? = nil) {
        cancelHoldTimer()
        cancelPendingConfirmation()
        endExplorationIfNeeded()
        phase = .exploring
        resetTapTracking()
        if let announcement {
            speechGuide.speak(announcement)
        }
    }

    private func cancelWidgetCreation(widgetID: UUID, announcement: String) {
        audioModel.cancelWidgetCreation(id: widgetID)
        transitionToExploring(announcement: announcement)
    }

    private func startDictation(for widgetID: UUID) {
        guard !didStartDictationForTouch else { return }
        guard case .naming(let activeWidgetID, _) = phase, activeWidgetID == widgetID else { return }

        didStartDictationForTouch = true
        phase = .dictating(widgetID: widgetID)
        endExplorationIfNeeded()
        speechGuide.beginDictation {
            phase = .naming(widgetID: widgetID, awaitingRetry: true)
            speakNamingPrompt(awaitingRetry: true)
        }
    }

    private func handleTouchChanged(at location: CGPoint, canvasSize: CGSize) {
        switch phase {
        case .placing(let widgetID), .moving(let widgetID):
            beginExplorationIfNeeded()
            audioModel.moveWidget(id: widgetID, to: location, canvasSize: canvasSize)
            PHASEManager.shared.updateFinger(location, in: canvasSize)
            return
        case .naming(let widgetID, _):
            startDictationIfHeldLongEnough(widgetID: widgetID)
            return
        case .dictating:
            return
        case .confirming, .exploring:
            break
        }

        guard phase.allowsSpatialExploration else { return }

        beginExplorationIfNeeded()
        PHASEManager.shared.updateFinger(location, in: canvasSize)
    }

    private func handleTouchEnded(at location: CGPoint, start: CGPoint, canvasSize: CGSize) {
        let touchDuration = touchBeganAt.map { Date().timeIntervalSince($0) } ?? 0
        let movement = hypot(location.x - start.x, location.y - start.y)
        let isShortTouch = movement < tapMoveThreshold

        defer {
            cancelHoldTimer()
            touchBeganAt = nil
            didStartDictationForTouch = false
        }

        switch phase {
        case .dictating(let widgetID):
            endExplorationIfNeeded()
            speechGuide.endDictation { result in
                switch result {
                case .success(let name):
                    let resolvedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    audioModel.renameWidget(id: widgetID, name: resolvedName)
                    cancelPendingConfirmation()
                    resetTapTracking()
                    phase = .confirming(widgetID: widgetID, name: resolvedName)
                    speechGuide.speak("Named it \(resolvedName). Tap once to place it. Double tap to cancel.")
                case .failure:
                    phase = .naming(widgetID: widgetID, awaitingRetry: true)
                    speakNamingPrompt(awaitingRetry: true)
                }
            }
            return

        case .naming(let widgetID, _):
            endExplorationIfNeeded()
            if isShortTouch, isDoubleTap(at: location, within: doubleTapDistance) {
                cancelWidgetCreation(widgetID: widgetID, announcement: "Widget creation cancelled.")
                return
            }
            return

        case .confirming(let widgetID, _):
            endExplorationIfNeeded()
            guard isShortTouch else { return }

            if isDoubleTap(at: location, within: doubleTapDistance) {
                cancelWidgetCreation(widgetID: widgetID, announcement: "Widget creation cancelled.")
                return
            }

            cancelPendingConfirmation()
            let work = DispatchWorkItem {
                guard case .confirming(let activeWidgetID, _) = phase, activeWidgetID == widgetID else { return }
                pendingConfirmation = nil
                phase = .placing(widgetID: widgetID)
                if let widget = audioModel.authoredWidgets.first(where: { $0.id == widgetID }) {
                    speechGuide.speak("Place \(widget.name). Drag to position, then lift to set.")
                }
            }
            pendingConfirmation = work
            DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapThreshold, execute: work)
            return

        case .placing(let widgetID):
            cancelPendingConfirmation()
            endExplorationIfNeeded()
            audioModel.moveWidget(id: widgetID, to: location, canvasSize: canvasSize)
            if let placedWidget = audioModel.authoredWidgets.first(where: { $0.id == widgetID }) {
                speechGuide.speak("\(placedWidget.name) placed.")
            }
            transitionToExploring()
            return

        case .moving(let widgetID):
            if isShortTouch, isDoubleTap(at: location, within: doubleTapDistance) {
                transitionToExploring(announcement: "Move cancelled.")
                return
            }

            endExplorationIfNeeded()
            audioModel.moveWidget(id: widgetID, to: location, canvasSize: canvasSize)
            if let movedWidget = audioModel.authoredWidgets.first(where: { $0.id == widgetID }) {
                speechGuide.speak("\(movedWidget.name) placed.")
            }
            transitionToExploring()
            return

        case .exploring:
            defer { endExplorationIfNeeded() }

            guard isShortTouch else { return }

            if let widget = audioModel.widget(at: location, radius: widgetDiameter / 2) {
                if isDoubleTap(at: location, within: widgetDiameter) {
                    audioModel.selectWidget(id: widget.id)
                    phase = .moving(widgetID: widget.id)
                    speechGuide.speak("\(widget.name) selected. Drag to move, then lift to set. Double tap to cancel.")
                }
                return
            }

            if isDoubleTap(at: location, within: doubleTapDistance) {
                return
            }

            endExplorationIfNeeded()

            guard audioModel.canPlaceWidget(at: location, in: canvasSize),
                  let newID = audioModel.createWidget(at: location, canvasSize: canvasSize) else {
                if audioModel.authoredWidgets.count >= 8 {
                    speechGuide.speak("Eight widgets. No more room.")
                }
                return
            }

            phase = .naming(widgetID: newID, awaitingRetry: false)
            speakNamingPrompt(awaitingRetry: false)
        }
    }

    private func startDictationIfHeldLongEnough(widgetID: UUID) {
        guard let began = touchBeganAt else { return }
        guard Date().timeIntervalSince(began) >= holdThreshold else { return }
        startDictation(for: widgetID)
    }

    private func isDoubleTap(at location: CGPoint, within maxDistance: CGFloat) -> Bool {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastCanvasTapTime)
        let tapDistance = hypot(location.x - lastCanvasTapPoint.x, location.y - lastCanvasTapPoint.y)
        let isDoubleTap = elapsed < doubleTapThreshold && tapDistance < maxDistance

        lastCanvasTapTime = now
        lastCanvasTapPoint = location
        return isDoubleTap
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}
