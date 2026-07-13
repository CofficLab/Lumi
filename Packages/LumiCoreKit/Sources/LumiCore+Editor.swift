import Foundation

public extension LumiCore {
    // MARK: - Editor Service

    /// 编辑器服务（由外部通过 `LumiCore.boot(editorFactory:)` 工厂创建，自动注册到服务表）。
    /// 使用 `AbstractEditorServicing` 抽象协议，避免 LumiCoreKit 反向依赖 EditorService（会成环）。
    @MainActor public static private(set) var editorService: (any AbstractEditorServicing)?

    // MARK: - Editor Bootstrap Factory

    /// EditorBootstrap 工厂闭包类型。
    ///
    /// 接收 LumiAgentToolProviding（通常是 `PluginService`），返回具体的 `EditorService`。
    /// 通过泛型 `Service` 保留具体类型信息，使 `LumiCore` 在 boot 内部既能注册抽象协议
    /// （`AbstractEditorServicing`），也能注册具体类型（具体 `Service`）。
    ///
    /// 使用 `@escaping` 的工厂闭包请在调用点（`boot`、`bootstrapEditor`）的参数上显式标注。
    public typealias EditorBootstrapFactory<Service: AbstractEditorServicing> =
        @MainActor (any LumiAgentToolProviding) throws -> Service

    // MARK: - Editor Bootstrap

    /// 启动编辑器服务（泛型版本，由 `boot` 内部调用）。
    ///
    /// - 接收 `EditorBootstrapFactory<Service>` 创建具体实例；
    /// - 存入 `editorService`（抽象类型）；
    /// - 注册抽象协议 `AbstractEditorServicing` 到服务表（供通用解析使用）；
    /// - 注册具体类型 `Service` 到服务表（供具体解析使用，避免上层再做 `as?` 转换）。
    ///
    /// - Parameters:
    ///   - provider: Agent Tool 贡献者（通常是 `PluginService`）。
    ///   - factory: 编辑器工厂闭包，由 LumiApp 提供。
    @MainActor
    static func bootstrapEditor<Service: AbstractEditorServicing>(
        provider: any LumiAgentToolProviding,
        factory: @escaping EditorBootstrapFactory<Service>
    ) throws {
        let service = try factory(provider)
        editorService = service
        registerService((any AbstractEditorServicing).self, service)
        registerService(Service.self, service)
    }
}