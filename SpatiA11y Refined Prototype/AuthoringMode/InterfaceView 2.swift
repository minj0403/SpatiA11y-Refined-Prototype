import SwiftUI

enum InterfaceMode {
    case authoring
    case exploration
}

struct InterfaceView: View {
    @ObservedObject var audioModel: AudioViewModel
    let mode: InterfaceMode

    @State private var explorationDot: CGPoint = .zero
    @State private var activeAuthoringWidget: WidgetID? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground)

                if mode == .authoring {
                    authoringCanvas
                } else {
                    explorationCanvas(geo: geo)
                }

                VStack(spacing: 12) {
                    HStack {
                        if mode == .authoring {
                            Text("Placed \(audioModel.placedWidgetPositions.count)/\(audioModel.maxAuthorableWidgets)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Button("Clear") {
                                audioModel.clearAuthoredLayout()
                            }
                            .font(.caption)
                        } else {
                            Text("Explore authored layout")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .gesture(activeGesture(in: geo))
            .onChange(of: mode) { newMode in
                PHASEManager.shared.fingerUp()
                audioModel.updateTouchState(false)

                if newMode == .exploration {
                    explorationDot = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    PHASEManager.shared.updateFinger(explorationDot, in: geo.size)
                }
            }
            .onAppear {
                explorationDot = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                PHASEManager.shared.updateFinger(explorationDot, in: geo.size)
            }
        }
    }

    private var authoringCanvas: some View {
        ZStack {
            // Blank canvas. Existing placements are shown only as small visual anchors.
            ForEach(WidgetID.allCases) { widget in
                if let point = audioModel.placedWidgetPositions[widget] {
                    widgetMarker(widget.rawValue, at: point, isPreview: false)
                }
            }

            if let previewWidget = audioModel.previewWidget,
               let previewPosition = audioModel.previewPosition {
                widgetMarker(previewWidget.rawValue, at: previewPosition, isPreview: true)
            }
        }
    }

    private func explorationCanvas(geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(WidgetID.allCases) { widget in
                if let point = audioModel.placedWidgetPositions[widget] {
                    widgetMarker(widget.rawValue, at: point, isPreview: false)
                }
            }

            Circle()
                .frame(width: 24, height: 24)
                .position(
                    explorationDot == .zero
                    ? CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                    : explorationDot
                )
        }
    }

    private func widgetMarker(_ name: String, at point: CGPoint, isPreview: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .frame(width: isPreview ? 36 : 30, height: isPreview ? 36 : 30)
                .opacity(isPreview ? 0.45 : 1.0)
            Text(name)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .position(point)
    }

    private func activeGesture(in geo: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                switch mode {
                case .authoring:
                    handleAuthoringChanged(value, in: geo.size)
                case .exploration:
                    handleExplorationChanged(value, in: geo.size)
                }
            }
            .onEnded { value in
                switch mode {
                case .authoring:
                    handleAuthoringEnded(value, in: geo.size)
                case .exploration:
                    handleExplorationEnded(value, in: geo.size)
                }
            }
    }

    // MARK: - Authoring

    private func handleAuthoringChanged(_ value: DragGesture.Value, in size: CGSize) {
        if activeAuthoringWidget == nil {
            guard let widget = audioModel.beginAuthoringPreview(at: value.location) else { return }
            activeAuthoringWidget = widget
            PHASEManager.shared.beginAuthoringWidget(map(widget), at: value.location, in: size)
        } else if let widget = activeAuthoringWidget {
            audioModel.updateAuthoringPreview(to: value.location)
            PHASEManager.shared.updateAuthoringWidget(map(widget), to: value.location, in: size)
        }
    }

    private func handleAuthoringEnded(_ value: DragGesture.Value, in size: CGSize) {
        guard let widget = activeAuthoringWidget else { return }
        _ = audioModel.commitAuthoringPreview(at: value.location)
        PHASEManager.shared.finishAuthoringWidget(map(widget), at: value.location, in: size)
        activeAuthoringWidget = nil
    }

    // MARK: - Exploration

    private func handleExplorationChanged(_ value: DragGesture.Value, in size: CGSize) {
        explorationDot = value.location
        audioModel.updateTouchState(true)
        PHASEManager.shared.fingerDown()
        PHASEManager.shared.updateFinger(value.location, in: size)
    }

    private func handleExplorationEnded(_ value: DragGesture.Value, in size: CGSize) {
        audioModel.updateTouchState(false)
        PHASEManager.shared.fingerUp()

        let dx = value.translation.width
        let dy = value.translation.height
        let distance = sqrt(dx * dx + dy * dy)

        if distance < 10 {
            PHASEManager.shared.handleSingleTap()
        }
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
