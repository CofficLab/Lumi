import Foundation

// MARK: - Editor Service

extension LumiCore {
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
    func bootstrapEditor<Service: AbstractEditorServicing>(
        provider: any LumiAgentToolProviding,
        factory: @escaping EditorBootstrapFactory<Service>
    ) throws {
        let service = try factory(provider)
        editorService = service
        registerService((any AbstractEditorServicing).self, service)
        registerService(Service.self, service)
    }
}