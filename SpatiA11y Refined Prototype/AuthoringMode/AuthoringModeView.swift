import SwiftUI

struct AuthoringModeView: View {
    @ObservedObject var audioModel: AudioViewModel

    @State private var touchStart: CGPoint = .zero
    @State private var currentTouch: CGPoint = .zero
    @State private var draggedWidgetID: UUID?

    @State private var namingWidgetID: UUID?
    @State private var draftName = ""
    @State private var pendingPlacementWidgetID: UUID?
    @State private var pendingMoveWidgetID: UUID?

    private let widgetDiameter: CGFloat = 64
    private let tapMoveThreshold: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ForEach(audioModel.authoredWidgets) { widget in
                    widgetView(widget)
                        .position(widget.position)
                        .highPriorityGesture(
                            TapGesture(count: 2)
                                .onEnded {
                                    audioModel.selectWidget(id: widget.id)
                                    pendingMoveWidgetID = widget.id
                                    if let selected = audioModel.authoredWidgets.first(where: { $0.id == widget.id }) {
                                        audioModel.announceWidgetReadyToMove(name: selected.name)
                                    } else {
                                        audioModel.speakWidgetName(id: widget.id)
                                    }
                                }
                        )
                }

                VStack {
                    Text("Spatial mode")
                        .font(.title2)
                        .bold()

                    Text("Single tap empty space to create a new widget. Double tap a widget to reposition it.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Spacer()

                    if pendingPlacementWidgetID != nil {
                        Text("Placement mode: drag your finger to place the newly named widget.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    if pendingMoveWidgetID != nil {
                        Text("Move mode: drag your finger to reposition the selected widget.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Text("\(audioModel.authoredWidgets.count)/8 widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom)
                }
                .padding()
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let pendingID = pendingPlacementWidgetID {
                            audioModel.moveWidget(
                                id: pendingID,
                                to: value.location,
                                canvasSize: geo.size
                            )
                            return
                        }
                        
                        if let pendingID = pendingMoveWidgetID {
                            audioModel.moveWidget(
                                id: pendingID,
                                to: value.location,
                                canvasSize: geo.size
                            )
                            return
                        }

                        touchStart = value.startLocation
                        currentTouch = value.location

                        PHASEManager.shared.fingerDown()
                        PHASEManager.shared.updateFinger(value.location, in: geo.size)
                    }
                    .onEnded { value in
                        if let pendingID = pendingPlacementWidgetID {
                            audioModel.moveWidget(
                                id: pendingID,
                                to: value.location,
                                canvasSize: geo.size
                            )
                            if let placedWidget = audioModel.authoredWidgets.first(where: { $0.id == pendingID }) {
                                audioModel.announceWidgetPlaced(name: placedWidget.name)
                            }
                            pendingPlacementWidgetID = nil
                            return
                        }
                        
                        if let pendingID = pendingMoveWidgetID {
                            audioModel.moveWidget(
                                id: pendingID,
                                to: value.location,
                                canvasSize: geo.size
                            )
                            if let movedWidget = audioModel.authoredWidgets.first(where: { $0.id == pendingID }) {
                                audioModel.announceWidgetPlaced(name: movedWidget.name)
                            }
                            pendingMoveWidgetID = nil
                            return
                        }

                        PHASEManager.shared.fingerUp()

                        let dx = value.location.x - value.startLocation.x
                        let dy = value.location.y - value.startLocation.y
                        let distance = sqrt(dx * dx + dy * dy)

                        guard distance < tapMoveThreshold else { return }

                        if audioModel.canPlaceWidget(at: value.location, in: geo.size),
                           let newID = audioModel.createWidget(
                            at: value.location,
                            canvasSize: geo.size
                           ) {
                            namingWidgetID = newID
                            draftName = ""
                            audioModel.announceWidgetCreatedNeedsName()
                        }
                    }
            )
            .sheet(item: $namingWidgetID) { widgetID in
                VStack(spacing: 20) {
                    Text("Name this widget")
                        .font(.headline)

                    TextField("Widget name", text: $draftName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Text("You can use the iPhone keyboard microphone for speech-to-text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Button("Cancel", role: .cancel) {
                            audioModel.cancelWidgetCreation(id: widgetID)
                            namingWidgetID = nil
                        }
                        .buttonStyle(.bordered)

                        Button("Submit") {
                            let finalName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let resolvedName = finalName.isEmpty ? "Untitled Widget" : finalName
                            audioModel.renameWidget(
                                id: widgetID,
                                name: resolvedName
                            )
                            audioModel.announceWidgetReadyForPlacement(name: resolvedName)
                            pendingPlacementWidgetID = widgetID
                            namingWidgetID = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
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
        .accessibilityLabel(widget.name)
        .accessibilityHint("Double tap to select and hear the name. Drag to move.")
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}
