import SwiftUI

struct AuthoringModeView: View {
    @ObservedObject var audioModel: AudioViewModel

    @State private var touchStart: CGPoint = .zero
    @State private var currentTouch: CGPoint = .zero
    @State private var draggedWidgetID: UUID?

    @State private var namingWidgetID: UUID?
    @State private var draftName = ""

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
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if draggedWidgetID == nil {
                                        draggedWidgetID = widget.id
                                    }

                                    audioModel.selectWidget(id: widget.id)
                                    audioModel.moveWidget(
                                        id: widget.id,
                                        to: value.location,
                                        canvasSize: geo.size
                                    )

                                    PHASEManager.shared.fingerDown()
                                    PHASEManager.shared.updateFinger(value.location, in: geo.size)
                                }
                                .onEnded { _ in
                                    draggedWidgetID = nil
                                    PHASEManager.shared.fingerUp()
                                }
                        )
                        .onTapGesture(count: 3) {
                            audioModel.speakWidgetName(id: widget.id)
                        }
                        .onTapGesture(count: 2) {
                            audioModel.selectWidget(id: widget.id)
                        }
                }

                VStack {
                    Text("Authoring Mode")
                        .font(.title2)
                        .bold()

                    Text("Single tap empty space to create. Double tap widget to select. Triple tap to hear name.")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    Spacer()

                    Text("\(audioModel.authoredWidgets.count)/10 widgets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom)
                }
                .padding()
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        touchStart = value.startLocation
                        currentTouch = value.location

                        PHASEManager.shared.fingerDown()
                        PHASEManager.shared.updateFinger(value.location, in: geo.size)
                    }
                    .onEnded { value in
                        PHASEManager.shared.fingerUp()

                        let dx = value.location.x - value.startLocation.x
                        let dy = value.location.y - value.startLocation.y
                        let distance = sqrt(dx * dx + dy * dy)

                        guard distance < tapMoveThreshold else { return }

                        if audioModel.widget(at: value.location, radius: widgetDiameter / 2) == nil {
                            if let newID = audioModel.createWidget(
                                at: value.location,
                                canvasSize: geo.size
                            ) {
                                namingWidgetID = newID
                                draftName = ""
                            }
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

                    Button("Save") {
                        let finalName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        audioModel.renameWidget(
                            id: widgetID,
                            name: finalName.isEmpty ? "Untitled Widget" : finalName
                        )
                        namingWidgetID = nil
                    }
                    .buttonStyle(.borderedProminent)
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
        .accessibilityHint("Double tap to select. Triple tap to hear name. Drag to move.")
    }
}

extension UUID: Identifiable {
    public var id: UUID { self }
}
