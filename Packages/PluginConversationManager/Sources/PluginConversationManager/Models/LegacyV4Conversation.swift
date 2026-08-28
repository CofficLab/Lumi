import Foundation
import SwiftData

// MARK: - v4 Legacy Conversation Model (verbatim from Lumi 4.x)
//
// 用于以 SwiftData 打开 v4 旧库 `Core/Lumi.db` 读取历史会话。
//
// ⚠️ 两个不可违背的硬约束:
// 1. 字段名 / 类型 / 可空性 / @Attribute 严禁修改 —— SwiftData 用 schema 比对。
// 2. 【关键】类名必须与 v4 库里的实体名完全一致 —— SwiftData 用「类名」推断实体名
//    并匹配库里的表。v4 库 Z_PRIMARYKEY 表记录的实体名是 Conversation。若改类名,
//    SwiftData 会认为库里没有该实体、把原表当孤立删除,导致 fetch 永远返回空。
//    因此类名不能用前缀,必须保持 v4 原名 `Conversation`。
//
// 只迁移会话,故只需 Conversation 实体(消息由 MessageManager 插件独立迁移)。
// 迁移窗口期结束后本文件整体移除。
@Model
final class Conversation {
    @Attribute(.unique) var id: UUID
    var projectId: String?
    var title: String
    var preview: String
    var createdAt: Date
    var updatedAt: Date
    var providerId: String?
    var model: String?
    var chatMode: String?
    var verbosity: String?
    var languagePreference: String?

    init(
        id: UUID = UUID(),
        projectId: String? = nil,
        title: String,
        preview: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerId: String? = nil,
        model: String? = nil,
        chatMode: String? = nil,
        verbosity: String? = nil,
        languagePreference: String? = nil
    ) {
        self.id = id
        self.projectId = projectId
        self.title = title
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerId = providerId
        self.model = model
        self.chatMode = chatMode
        self.verbosity = verbosity
        self.languagePreference = languagePreference
    }
}
