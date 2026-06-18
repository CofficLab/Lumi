import LumiCoreKit
import LumiUI
import SwiftUI

struct TurnCompletedMessageView: View {
    let message: LumiChatMessage

    var body: some View {
        AppLabeledDivider(
            title: "结束",
            detail: message.createdAt.formatted(date: .omitted, time: .standard)
        )
        .padding(.vertical, 8)
    }
}
