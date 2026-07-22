import Foundation
import SwiftUI

/// 输入状态（插件内部共享）
@MainActor
final class InputState: ObservableObject {
    /// 当前输入框的文本
    @Published var text: String = ""

    init() {}
}
