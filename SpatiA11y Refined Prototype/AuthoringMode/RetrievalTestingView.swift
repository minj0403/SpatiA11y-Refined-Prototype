import SwiftUI

struct RetrievalTrialResult: Identifiable, Equatable {
    let id = UUID()
    let widgetID: UUID
    let targetName: String
    let duration: TimeInterval
    let presentationOrder: Int
}

private enum RetrievalTestPhase: Equatable {
    case idle
    case searching(targetID: UUID)
    case completed
}

struct RetrievalTestingView: View {
    @ObservedObject var audioModel: AudioViewModel

    @State private var speechGuide = SpatialSpeechGuide()
    @State private var phase: RetrievalTestPhase = .idle
    @State private var trialQueue: [AuthoringWidget] = []
    @State private var results: [RetrievalTrialResult] = []
    @State private var trialStartedAt: Date?
    @State private var correctHoldBeganAt: Date?
    @State private var isExploring = false
    @State private var hasPreparedSession = false
    @State private var isCompletingTrial = false

    private let widgetDiameter: CGFloat = 64
    private let confirmationHoldDuration: TimeInterval = 1.0

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

                VStack(spacing: 12) {
                    Text("Retrieval testing")
                        .font(.title2)
                        .bold()

                    Text(statusDetail)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    if let activeTarget {
                        Text("Target: \(activeTarget.name)")
                            .font(.headline)
                    }

                    if let trialStartedAt, case .searching = phase {
                        TimelineView(.periodic(from: trialStartedAt, by: 0.1)) { context in
                            Text("Elapsed: \(formattedDuration(context.date.timeIntervalSince(trialStartedAt)))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !results.isEmpty {
                        resultsSummary
                    }

                    Spacer()
                }
                .padding()
                .allowsHitTesting(false)

                if audioModel.authoredWidgets.isEmpty {
                    emptyState
                } else {
                    SpatialExplorationTouchSurface(
                        onTouchBegan: { _ in
                            handleTouchBegan()
                        },
                        onTouchChanged: { location in
                            handleTouchChanged(at: location, canvasSize: geo.size)
                        },
                        onTouchEnded: { _, _ in
                            handleTouchEnded()
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                VStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Button("Restart session") {
                            restartSession()
                        }
                        .disabled(audioModel.authoredWidgets.isEmpty)

                        if case .completed = phase {
                            Button("Run again") {
                                restartSession()
                            }
                        }
                    }
                    .padding(.bottom)
                }
                .padding(.horizontal)
            }
            .accessibilityHidden(true)
            .onAppear {
                prepareSessionIfNeeded()
            }
            .onDisappear {
                endExplorationIfNeeded()
            }
            .onChange(of: audioModel.authoredWidgets) { widgets in
                if widgets.isEmpty {
                    resetSession()
                } else if !hasPreparedSession {
                    prepareSessionIfNeeded()
                }
            }
        }
    }

    private var activeTarget: AuthoringWidget? {
        guard case .searching(let targetID) = phase else { return nil }
        return audioModel.authoredWidgets.first(where: { $0.id == targetID })
    }

    private var statusDetail: String {
        if audioModel.authoredWidgets.isEmpty {
            return "Create widgets in Authoring before running retrieval."
        }

        switch phase {
        case .idle:
            return "Preparing retrieval session."
        case .searching:
            return "Find the target. Drag to explore, then hold on the item until it is confirmed."
        case .completed:
            return "Retrieval complete. Review the timings below."
        }
    }

    private var resultsSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Results")
                .font(.subheadline)
                .bold()

            ForEach(results) { result in
                Text("\(result.presentationOrder). \(result.targetName): \(formattedDuration(result.duration))")
                    .font(.caption.monospacedDigit())
            }

            Text("Total: \(formattedDuration(results.reduce(0) { $0 + $1.duration }))")
                .font(.caption)
                .bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No widgets to retrieve")
                .font(.headline)
            Text("Switch to Authoring and place items first.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func widgetView(_ widget: AuthoringWidget) -> some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: widgetDiameter, height: widgetDiameter)

            Circle()
                .stroke(Color.gray, lineWidth: 2)
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

    private func prepareSessionIfNeeded() {
        guard !audioModel.authoredWidgets.isEmpty else { return }
        guard !hasPreparedSession else { return }

        hasPreparedSession = true
        trialQueue = audioModel.authoredWidgets.shuffled()
        results = []
        phase = .idle
        speechGuide.speak("Retrieval task. Find each item when asked.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            beginNextTrial()
        }
    }

    private func restartSession() {
        endExplorationIfNeeded()
        hasPreparedSession = false
        prepareSessionIfNeeded()
    }

    private func resetSession() {
        endExplorationIfNeeded()
        hasPreparedSession = false
        trialQueue = []
        results = []
        phase = .idle
        trialStartedAt = nil
        correctHoldBeganAt = nil
    }

    private func beginNextTrial() {
        correctHoldBeganAt = nil
        endExplorationIfNeeded()

        guard let next = trialQueue.first else {
            phase = .completed
            speechGuide.speak("Retrieval complete.")
            return
        }

        trialQueue.removeFirst()
        phase = .searching(targetID: next.id)
        trialStartedAt = Date()
        speechGuide.speak("Find \(next.name).")
    }

    private func completeCurrentTrial(for target: AuthoringWidget) {
        guard !isCompletingTrial else { return }
        guard let trialStartedAt else { return }

        isCompletingTrial = true
        let duration = Date().timeIntervalSince(trialStartedAt)
        results.append(
            RetrievalTrialResult(
                widgetID: target.id,
                targetName: target.name,
                duration: duration,
                presentationOrder: results.count + 1
            )
        )

        self.trialStartedAt = nil
        correctHoldBeganAt = nil
        endExplorationIfNeeded()
        speechGuide.speak("\(target.name) found.")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isCompletingTrial = false
            beginNextTrial()
        }
    }

    private func handleTouchBegan() {
        guard case .searching = phase else { return }
        beginExplorationIfNeeded()
    }

    private func handleTouchChanged(at location: CGPoint, canvasSize: CGSize) {
        guard case .searching(let targetID) = phase else { return }

        beginExplorationIfNeeded()
        PHASEManager.shared.updateFinger(location, in: canvasSize)

        if let widget = audioModel.widget(at: location, radius: widgetDiameter / 2),
           widget.id == targetID {
            if correctHoldBeganAt == nil {
                correctHoldBeganAt = Date()
            } else if let began = correctHoldBeganAt,
                      Date().timeIntervalSince(began) >= confirmationHoldDuration,
                      let target = activeTarget {
                completeCurrentTrial(for: target)
            }
        } else {
            correctHoldBeganAt = nil
        }
    }

    private func handleTouchEnded() {
        correctHoldBeganAt = nil
        endExplorationIfNeeded()
    }

    private func beginExplorationIfNeeded() {
        guard !isExploring else { return }
        isExploring = true
        PHASEManager.shared.fingerDown()
    }

    private func endExplorationIfNeeded() {
        guard isExploring else { return }
        isExploring = false
        PHASEManager.shared.fingerUp()
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        String(format: "%.1fs", duration)
    }
}
