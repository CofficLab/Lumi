import Foundation
import KitLLM
import ProviderConversation

/// 推理弹层按模型能力裁剪后的可选项。
///
/// 「关闭思考」在不同模型上语义不同：能真关的模型关闭项直接生效，强制思考的
/// 模型关闭项会降为最低档位，既不能关也不认档位的模型只保留关闭项并说明原因。
/// UI 必须按模型能力裁剪，否则用户会看到「关了思考，消息里还是有思考」。
struct ReasoningMenuOptions: Equatable {

    /// 「关闭」项的可用性。
    enum OffAvailability: Equatable {
        /// 可以真正关闭思考。
        case available
        /// 模型强制思考：关闭会降为指定档位。
        case degradedToEffort(ReasoningEffort)
        /// 模型不支持关闭思考。
        case unsupported
    }

    /// 可选档位（已按模型能力过滤）。
    let efforts: [ReasoningEffort]

    /// 「关闭」项的可用性。
    let off: OffAvailability

    /// 按模型能力推导弹层选项。
    ///
    /// 模型未声明能力时保持通用行为：档位全开、关闭可用。
    static func make(capability: LLMReasoningCapability?) -> ReasoningMenuOptions {
        guard let capability else {
            return ReasoningMenuOptions(efforts: ReasoningEffort.allCases, off: .available)
        }

        let efforts: [ReasoningEffort]
        if capability.supportedEfforts.isEmpty {
            efforts = []
        } else {
            efforts = ReasoningEffort.allCases.filter {
                capability.supportedEfforts.contains($0.rawValue)
            }
        }

        let off: OffAvailability
        switch capability.offStrategy {
        case .disableThinkingParameter:
            off = .available
        case .lowestEffort(let effort):
            off = .degradedToEffort(ReasoningEffort(rawValue: effort) ?? .low)
        case .omitParameters:
            off = .unsupported
        }

        return ReasoningMenuOptions(efforts: efforts, off: off)
    }

    /// 当前选择**实际**对应的推理档位。
    ///
    /// 强制思考的模型上「关闭」实际会降为最低档位，chip 必须显示真实档位，
    /// 否则会出现「显示关闭、请求里却是思考」的错觉。
    func effectiveEffort(for selected: ReasoningEffort?) -> ReasoningEffort? {
        guard selected == nil, case .degradedToEffort(let effort) = off else {
            return selected
        }
        return effort
    }
}
