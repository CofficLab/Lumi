import Foundation
import LumiKernel
import LumiUI
import SwiftUI

/// MessageRenderer 插件 OnReady 阶段钩子
///
/// MessageRendererManager 服务及所有内置核心渲染器的注册已在 OnBoot 阶段完成。
/// 此钩子保留为空,以便未来扩展需要在所有服务就绪后执行的异步初始化逻辑。
@MainActor
public struct MessageRendererOnReadyHook {
    public init() {}

    /// 执行 onReady
    public func execute(_ kernel: LumiKernel) throws {
        // 所有注册已迁移至 OnBoot,这里保持为空。
    }
}
