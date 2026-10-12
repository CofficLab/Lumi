import Foundation

/// ACP Agent 身份与行为配置。
///
/// headless 进程没有 App Bundle，无法读取 Info.plist，
/// 因此 agent 标识信息由装配层显式注入。
public struct ACPConfig: Sendable {
    /// 程序化标识（ACP `agentInfo.name`）。
    public var agentName: String
    /// 面向 UI 展示的名称（ACP `agentInfo.title`）。
    public var agentTitle: String
    /// 实现版本（ACP `agentInfo.version`）。
    public var agentVersion: String

    public init(agentName: String, agentTitle: String, agentVersion: String) {
        self.agentName = agentName
        self.agentTitle = agentTitle
        self.agentVersion = agentVersion
    }

    /// 默认配置：名称沿用 Lumi，版本在打包阶段由装配层覆盖。
    public static let `default` = ACPConfig(
        agentName: "lumi-acp",
        agentTitle: "Lumi ACP",
        agentVersion: "0.1.0"
    )
}
