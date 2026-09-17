import SwiftUI

struct NativeControlRootOverlay: View {
    let content: AnyView
    @ObservedObject var state: NativeControlCoordinator

    var body: some View {
        ZStack {
            content.disabled(state.blocksLumi)
            if state.blocksLumi {
                Rectangle().fill(.regularMaterial)
                NativeControlStatusView(state: state)
                    .padding(28)
                    .frame(maxWidth: 420)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
            }
        }
    }
}
