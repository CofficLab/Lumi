import SwiftTerm
import SwiftUI

struct TerminalSessionContainerView: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        NativeTerminalHostView(session: session)
            .padding(10)
            .background(Color(nsColor: session.terminalView.nativeBackgroundColor))
    }
}
