import Foundation

/// Worker 描述符（由插件提供）。
///
/// 内核只认 `id`（字符串），其余字段用于构建 worker 的展示信息与 system prompt。
struct WorkerAgentDescriptor: Sendable, Equatable {
    let id: String
    let displayName: String
    let roleDescription: String
    let specialty: String
    let systemPrompt: String
    let order: Int
}

