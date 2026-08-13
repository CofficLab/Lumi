import Foundation

/// 内核服务依赖声明(协调器装配前的校验单元)。
///
/// `id` 用于在服务注册表中查存在性;`name` 只用于报错信息。
public struct LumiServiceRequirement: Sendable {
    public let name: String
    public let id: ObjectIdentifier

    /// - Parameters:
    ///   - type: 内核服务协议类型(如 `MessageManaging.self`)。
    ///   - name: 报错展示名;默认取类型名。
    public init<T>(_ type: T.Type, name: String? = nil) {
        self.id = ObjectIdentifier(type)
        self.name = name ?? String(describing: type)
    }
}

/// 内核协调器协议
///
/// 协调层(Coordinators/)的职责:把"服务 A 的变化引发服务 B 的动作"这类
/// **内核内部的联动逻辑**集中到一个可枚举、可单测的地方。
///
/// 每个协调器分两层:
/// - **装配层**(本协议):在 `startup()` 的协调装配阶段运行,声明必需服务
///   (`requiredServices`,缺失则 fail-fast),从 kernel 解析依赖,构造逻辑层
///   编排器,并把编排结果注册回内核(如 `SendFlowCoordinator` 注册
///   `MessageSending` 实现)。
/// - **逻辑层**(如 `LumiMessageSender`):依赖全部构造注入,不持有 kernel,
///   单测时直接喂 mock 即可验证全部联动规则。
///
/// 新增协调器 = 在 Coordinators/ 新建一个文件 + 在
/// `LumiCoordinatorRegistry.makeDefault()` 里加一行;`startup()` 本身不再改动。
@MainActor
public protocol LumiCoordinator {
    /// 稳定标识,用于日志与去重。
    var id: String { get }

    /// 本协调器必需的已注册内核服务;装配前统一校验,缺失即抛错(fail-fast)。
    var requiredServices: [LumiServiceRequirement] { get }

    /// 装配:解析依赖 → 构造编排器 → 接线(注册回调 / 注册成内核服务)。
    func start(kernel: KernelLumi) throws
}

/// 内核协调器注册表
///
/// `KernelLumi.startup()` 在插件服务注册完毕(onBoot)之后、服务校验之前,
/// 调用 `startAll(kernel:)` 一次性完成协调层装配:
/// 先统一校验各协调器的依赖,再按注册顺序逐个 `start`。
@MainActor
public final class LumiCoordinatorRegistry {
    public private(set) var coordinators: [any LumiCoordinator] = []

    public init() {}

    /// 内核内置协调器:新增协调器在此登记。
    ///
    /// 当前没有内置协调器(发送等链路由插件实现);将来某条"纯内核实现"的
    /// 联动链可在此 `register`,即可获得统一装配 + 依赖校验 + 单测支持。
    public static func makeDefault() -> LumiCoordinatorRegistry {
        LumiCoordinatorRegistry()
    }

    public func register(_ coordinator: any LumiCoordinator) {
        coordinators.append(coordinator)
    }

    /// 校验依赖并按注册顺序启动全部协调器。
    ///
    /// 任一协调器依赖缺失时抛出 `KernelLumiError.missingRequiredServices`,
    /// 带上协调器 id,便于定位是哪条链路没装配起来。
    public func startAll(kernel: KernelLumi) throws {
        for coordinator in coordinators {
            let missing = coordinator.requiredServices
                .filter { !kernel.isServiceRegistered($0.id) }
                .map(\.name)
            guard missing.isEmpty else {
                throw KernelLumiError.missingRequiredServices(
                    missing.map { "\($0) (required by \(coordinator.id))" }
                )
            }
            try coordinator.start(kernel: kernel)
        }
    }
}
