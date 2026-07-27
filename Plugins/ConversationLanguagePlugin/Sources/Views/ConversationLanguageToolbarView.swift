import LumiKernel
import SwiftUI

struct ConversationLanguageToolbarView: View {
    @ObservedObject var kernel: LumiKernel

    var body: some View {
        LanguageToggleButton(kernel: kernel)
    }
}
