import SwiftUI
import AVFoundation

struct ControlConditionView: View {
    @ObservedObject var audioModel: AudioViewModel
    @State private var focusedIndex: Int = 0
    private let synth = AVSpeechSynthesizer()

    private var placedWidgets: [WidgetID] {
        WidgetID.allCases.filter { audioModel.placedWidgetPositions[$0] != nil }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)

            ForEach(placedWidgets) { widget in
                if let point = audioModel.placedWidgetPositions[widget] {
                    VStack(spacing: 6) {
                        Circle()
                            .frame(width: widget == focusedWidget ? 40 : 30,
                                   height: widget == focusedWidget ? 40 : 30)
                        Text(widget.rawValue)
                            .font(.caption2)
                    }
                    .position(point)
                }
            }

            VStack {
                Text("Control Condition")
                    .font(.title2)
                Text("Swipe to focus. Double tap to announce.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width < 0 {
                            moveFocusForward()
                        } else {
                            moveFocusBackward()
                        }
                    }
                }
        )
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    announceFocusedWidget()
                }
        )
    }

    private var focusedWidget: WidgetID? {
        guard !placedWidgets.isEmpty else { return nil }
        return placedWidgets[min(focusedIndex, placedWidgets.count - 1)]
    }

    private func moveFocusForward() {
        guard !placedWidgets.isEmpty else { return }
        focusedIndex = (focusedIndex + 1) % placedWidgets.count
    }

    private func moveFocusBackward() {
        guard !placedWidgets.isEmpty else { return }
        focusedIndex = (focusedIndex - 1 + placedWidgets.count) % placedWidgets.count
    }

    private func announceFocusedWidget() {
        guard let widget = focusedWidget else { return }
        let utterance = AVSpeechUtterance(string: widget.rawValue)
        utterance.rate = 0.5
        synth.stopSpeaking(at: .immediate)
        synth.speak(utterance)
    }
}
