import SwiftUI

/// Toast容器视图
struct ToastContainer: View {
    @ObservedObject var toastManager: MagicToastManager

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(toastManager.toasts) { toast in
                    if toast.displayMode == .banner {
                        ToastView(toast: toast, onDismiss: toastManager.dismiss)
                            .padding(.top, 60)
                            .positioned(for: toast.displayMode, in: geometry)
                    } else {
                        ToastView(toast: toast, onDismiss: toastManager.dismiss)
                            .padding(.horizontal, 16)
                            .positioned(for: toast.displayMode, in: geometry)
                    }
                }
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: toastManager.toasts)
        }
    }

}



#if DEBUG
    #Preview {
        MagicToastExampleView()
            .frame(width: 600, height: 600)
            .withMagicToast()
    }
#endif
