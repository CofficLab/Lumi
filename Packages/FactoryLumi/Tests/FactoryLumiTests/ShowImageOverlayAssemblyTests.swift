import Foundation
import Testing
@testable import FactoryLumi

/// 「ShowImage」插件 overlay 的装配层接线验证。
///
/// ## 为什么要有这组用例
///
/// `show_image` 工具成功后只写 `ShowImageState` 单例；把状态真正渲染成
/// 预览面板的 `ShowImageOverlay` 是一个纯 SwiftUI 包装视图，只有装配层
/// 把它挂到主视图树上用户才能看到图片。插件自身的测试覆盖工具与状态
/// 行为，但装配层漏挂不会让它们失败——只会让功能静默消失。
@MainActor
@Suite("FactoryLumi · PluginShowImage")
struct ShowImageOverlayAssemblyTests {

    @Test("makeMainView 挂载 ShowImageOverlay")
    func mainViewMountsShowImageOverlay() throws {
        let view = try KernelFactory.makeMainView()

        let reflectedTypeNames = Self.allReflectedTypeNames(of: view, maxDepth: 8)
        #expect(
            reflectedTypeNames.contains { $0.contains("ShowImageOverlay") },
            Comment(
                rawValue: "makeMainView 输出的视图树应包含 ShowImageOverlay 包装，实际类型："
                    + reflectedTypeNames.joined(separator: "\n")
            )
        )
    }

    /// 沿 Mirror 递归收集视图树里出现的类型名。
    ///
    /// `AnyView` 的存储类型（`AnyViewStorage<被包装视图>`）会暴露内层
    /// 泛型参数，足以断言装配层真的挂上了 overlay 包装。深度上限防止
    /// 走进宿主对象引用后失控。
    private static func allReflectedTypeNames(of value: Any, maxDepth: Int) -> [String] {
        let mirror = Mirror(reflecting: value)
        var names = [String(describing: mirror.subjectType)]
        guard maxDepth > 0 else { return names }
        for child in mirror.children {
            names += allReflectedTypeNames(of: child.value, maxDepth: maxDepth - 1)
        }
        return names
    }
}
