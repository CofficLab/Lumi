import KernelLumi
import SwiftUI

struct PendingMessageResolverView: View {
    @ObservedObject var kernel: KernelLumi
    @StateObject private var boxHolder = PendingMessageBoxHolder()

    var body: some View {
        if let messageSending = kernel.messageSender {
            PendingMessageListView(
                kernel: kernel,
                box: boxHolder.box(for: messageSending)
            )
        } else {
            EmptyView()
        }
    }
}

@MainActor
private final class PendingMessageBoxHolder: ObservableObject {
    private(set) var box: ObservableMessageSendingBox?

    func box(for service: any MessageSending) -> ObservableMessageSendingBox {
        if let box, box.service === service { return box }
        let newBox = ObservableMessageSendingBox(service: service)
        box = newBox
        return newBox
    }
}
