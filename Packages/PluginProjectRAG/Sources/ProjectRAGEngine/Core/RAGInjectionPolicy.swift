import Foundation

/// 自动注入的置信度门槛与开关常量集中地。
///
/// 阈值判断在 Hook 内对协调器返回的结果做：语义结果需达到余弦阈值，
/// 或词法命中达到最小条数，二者满足其一才注入。原始分仅用于门槛与展示，
/// 跨路排序由 RRF 负责（见 CodeNavigationCoordinator）。
public enum RAGInjectionPolicy {
    /// 语义注入阈值（决策 D4 初值）。低于此分的语义片段视为噪声，不自动注入。
    /// 工具侧阈值更宽松（见 semanticResultThreshold）。
    public static let semanticScoreThreshold: Float = 0.50

    /// 工具侧语义结果阈值（Task 2.3 初值）：检索返回时丢弃低于此分的语义候选，
    /// 比注入门槛宽松——工具可见更多证据，注入只挑高置信。
    public static let semanticResultThreshold: Float = 0.30

    /// 没有达标语义结果时，至少需要这么多条词法命中才注入。
    public static let minLexicalHits = 2

    /// 自动注入用户开关的 UserDefaults key（默认 true）。设置 UI 在 Phase 4 暴露。
    public static let autoInjectEnabledKey = "projectRAG.autoInjectEnabled"

    /// 是否达到自动注入的置信度门槛。
    public static func shouldInject(results: [RAGSearchResult]) -> Bool {
        if results.contains(where: { $0.matchKind == .semantic && $0.score >= semanticScoreThreshold }) {
            return true
        }
        let lexicalHits = results.filter {
            $0.matchKind == .filesystemLexical || $0.matchKind == .indexedLexical
        }.count
        return lexicalHits >= minLexicalHits
    }
}