import Foundation

/// 用户在预览中右键选中的一个「区块」。
///
/// 由 `HTMLPreviewView` 注入的 JS 在右键命中某个 `data-block`（或兜底的语义块）时，
/// 经 `WKScriptMessageHandler` 回传，再由宿主插件（如 App Store Promo Designer）
/// 组装成草稿写入聊天输入框，从而把区块交给 LLM 讨论或修改。
public struct PromoBlockSelection: Sendable, Equatable {
    /// 区块机器标识，优先取 `data-block` 属性；兜底为标签名（如 `section`、`h1`）。
    public let blockID: String
    /// 给人看的区块标签，优先取 `data-block-label`；缺省回退到 `blockID`。
    public let label: String
    /// 该区块元素的 `outerHTML`，作为待修改内容的完整快照。
    public let outerHTML: String

    public init(blockID: String, label: String, outerHTML: String) {
        self.blockID = blockID
        self.label = label
        self.outerHTML = outerHTML
    }

    /// Decode the payload produced by the original block-selection bridge.
    ///
    /// Kept separate from the element-reference bridge so existing consumers can
    /// continue using the legacy callback without enabling the new context menu.
    static func decodeLegacyMessageBody(_ body: Any) -> PromoBlockSelection? {
        guard let body = body as? [String: Any],
              body["action"] as? String == "send" else { return nil }

        let blockID = body["blockID"] as? String ?? "block"
        let label = (body["label"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? blockID
        let outerHTML = body["outerHTML"] as? String ?? ""
        return PromoBlockSelection(blockID: blockID, label: label, outerHTML: outerHTML)
    }
}
