import Foundation
import SwiftUI

struct TerminalSessionContainerView: View {
    @ObservedObject var session: TerminalSession
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NativeTerminalHostView(session: session)
            .background(colorScheme == .dark
                ? Color(red: 0.11, green: 0.11, blue: 0.12)
                : .white
            )
    }
}
