import SwiftUI

struct ActivationRing: View {
    let radius: CGFloat

    var body: some View {
        Circle()
            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
            .frame(width: radius * 2, height: radius * 2)
            .foregroundStyle(.gray.opacity(0.5))
    }
}
