import Foundation
@testable import KernelLumi

/// 内核测试公共构造工具。
///
/// 提供 `makeKernel()` 等便利构造,统一协调器注册表的测试用法,
/// 避免每个测试文件重复样板。
@MainActor
enum KernelTestKit {
    /// 一个干净的内核实例(默认协调器注册表已含 SendFlowCoordinator)。
    static func makeKernel() -> KernelLumi {
        KernelLumi()
    }
}
