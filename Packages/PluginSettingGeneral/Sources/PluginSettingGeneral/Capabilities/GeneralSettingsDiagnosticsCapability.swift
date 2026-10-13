import ProviderDiagnostics

/// 通用设置页需要的最小诊断导出能力。
@MainActor
protocol GeneralSettingsDiagnosticsCapability: AnyObject {
    var isDiagnosticsAvailable: Bool { get }
    func makeDiagnosticsArchive() async throws -> DiagnosticsArchive
}

/// 默认实现：把 `DiagnosticsProviding` 收窄为本插件的诊断导出能力。
@MainActor
final class GeneralSettingsDiagnosticsCapabilityAdapter: GeneralSettingsDiagnosticsCapability {
    private let diagnosticsProvider: (any DiagnosticsProviding)?

    init(diagnosticsProvider: (any DiagnosticsProviding)?) {
        self.diagnosticsProvider = diagnosticsProvider
    }

    var isDiagnosticsAvailable: Bool {
        diagnosticsProvider != nil
    }

    func makeDiagnosticsArchive() async throws -> DiagnosticsArchive {
        guard let diagnosticsProvider else {
            throw GeneralSettingsCapabilityError.unavailable("诊断日志服务暂不可用。")
        }
        return try await diagnosticsProvider.makeDiagnosticsArchive()
    }
}