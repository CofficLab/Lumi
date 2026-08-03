import SwiftUI

struct OnboardingCursor: View {
    let position: CGPoint
    let isClicking: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .shadow(color: Color.accentColor.opacity(0.45), radius: 4)

            if isClicking {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(Color.accentColor.opacity(0.7), lineWidth: 2)
                        .frame(width: 18, height: 18)
                        .scaleEffect(isClicking ? 2.5 : 0.5)
                        .opacity(isClicking ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: 0.9)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.28),
                            value: isClicking
                        )
                }
            }
        }
        .position(position)
        .animation(.spring(response: 0.7, dampingFraction: 0.8), value: position)
    }
}

#Preview("Cursor") {
    OnboardingCursor(position: CGPoint(x: 80, y: 80), isClicking: true)
        .frame(width: 160, height: 160)
}
