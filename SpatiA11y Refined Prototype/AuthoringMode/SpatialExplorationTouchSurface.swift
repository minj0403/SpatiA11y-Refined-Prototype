import SwiftUI
import UIKit

struct SpatialExplorationTouchSurface: UIViewRepresentable {
    let onTouchBegan: (CGPoint) -> Void
    let onTouchChanged: (CGPoint) -> Void
    let onTouchEnded: (CGPoint, CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SpatialExplorationTouchView {
        let view = SpatialExplorationTouchView()
        view.coordinator = context.coordinator
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ uiView: SpatialExplorationTouchView, context: Context) {
        uiView.coordinator = context.coordinator
        context.coordinator.onTouchBegan = onTouchBegan
        context.coordinator.onTouchChanged = onTouchChanged
        context.coordinator.onTouchEnded = onTouchEnded
    }

    final class Coordinator {
        var onTouchBegan: ((CGPoint) -> Void)?
        var onTouchChanged: ((CGPoint) -> Void)?
        var onTouchEnded: ((CGPoint, CGPoint) -> Void)?
        var startLocation: CGPoint = .zero
    }
}

final class SpatialExplorationTouchView: UIView {
    var coordinator: SpatialExplorationTouchSurface.Coordinator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        isUserInteractionEnabled = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        coordinator?.startLocation = point
        coordinator?.onTouchBegan?(point)
        coordinator?.onTouchChanged?(point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let point = touches.first?.location(in: self) else { return }
        coordinator?.onTouchChanged?(point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let coordinator else { return }
        let point = touches.first?.location(in: self) ?? coordinator.startLocation
        coordinator.onTouchEnded?(point, coordinator.startLocation)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let coordinator else { return }
        let point = touches.first?.location(in: self) ?? coordinator.startLocation
        coordinator.onTouchEnded?(point, coordinator.startLocation)
    }
}

extension View {
    @ViewBuilder
    func spatialDirectTouchEnabled() -> some View {
        self
    }
}
