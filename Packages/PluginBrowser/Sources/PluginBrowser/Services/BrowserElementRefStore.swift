import Foundation

/// 元素 ref 的会话侧登记簿。
///
/// ref 的**稳定性主要来自 DOM**：`data-lumi-browser-ref` 属性挂在元素自身，
/// 页面没变时元素还在，ref 就还在，因此跨快照天然一致。
///
/// 本类负责 DOM 之外的部分：
///
/// - **输入规范化**：LLM 可能传来 `@lumi-3`、`lumi-3` 或裸数字 `3`，
///   统一成 `lumi-3` 这种内部形式。
/// - **stale 检测**：记录每个 ref 最近一次被快照时看到的角色与名称。
///   交互时若该 ref 已不在 DOM 中，给出「该元素已消失，请重新快照」
///   的明确提示，而不是笼统的失败——否则 LLM 会反复重试同一个死 ref。
@MainActor
final class BrowserElementRefStore {
    /// ref 已知的元素特征，用于生成可诊断的失效信息。
    struct ElementSignature: Sendable, Equatable {
        var role: String
        var name: String

        var description: String {
            name.isEmpty ? role : "\(role) \"\(name)\""
        }
    }

    private var signatures: [String: ElementSignature] = [:]
    /// 已确认不在页面中的 ref，附上失效原因。
    private var staleReasons: [String: String] = [:]

    /// 规范化 LLM 传入的 ref。
    ///
    /// - Returns: 规范化后的 ref；无法识别时返回 nil。
    func normalize(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("@") { value.removeFirst() }
        guard !value.isEmpty else { return nil }
        // 裸数字按旧版 index 语义补全：readPage 曾用 `lumi-1` 起的编号。
        if value.allSatisfy(\.isNumber) {
            value = "lumi-\(value)"
        }
        guard value.count <= 48,
              value.hasPrefix("lumi-"),
              value.dropFirst(5).allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") })
        else {
            return nil
        }
        return value
    }

    /// 登记快照中出现的元素。
    func register(signatures newSignatures: [String: ElementSignature]) {
        for (ref, signature) in newSignatures {
            signatures[ref] = signature
            staleReasons.removeValue(forKey: ref)
        }
    }

    /// 标记某个 ref 已不在页面中。
    func markStale(ref: String, reason: String) {
        staleReasons[ref] = reason
    }

    /// ref 的失效说明；未失效时返回 nil。
    func staleMessage(for ref: String) -> String? {
        guard let reason = staleReasons[ref] else { return nil }
        let known = signatures[ref].map { " (last seen: \(($0).description))" } ?? ""
        return "The element @\(ref)\(known) is no longer on the page: \(reason). Take a fresh browser_snapshot and retry with a current ref."
    }

    /// 该 ref 是否曾经被见过。
    ///
    /// 用于区分「LLM 编了一个不存在的 ref」和「ref 曾经存在但元素消失了」，
    /// 两者的恢复动作不同：前者多半是幻觉，后者要重新快照。
    func isKnown(_ ref: String) -> Bool {
        signatures[ref] != nil
    }

    /// 页面导航后清空登记簿。
    ///
    /// 换页后旧 ref 全部失效，但 DOM 属性还在时脚本会复用同一个 ref 字符串，
    /// 因此这里只清「已知特征」，让下一次快照重新登记。
    func reset() {
        signatures.removeAll()
        staleReasons.removeAll()
    }
}
