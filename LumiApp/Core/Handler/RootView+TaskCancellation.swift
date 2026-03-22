import SwiftUI

extension RootView {
    func onTaskCancellationRequested() {
        guard let conversationId = self.container.taskCancellationVM.conversationIdToCancel else { return }



        AppLogger.core.info("\(Self.t) 任务已取消 [\(String(conversationId.uuidString.prefix(8)))]")


        container.taskCancellationVM.consumeRequest()
    }
}
