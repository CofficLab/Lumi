import Foundation
import LumiComponentGit
import LumiComponentLayout

// MARK: - Git Component Types

public typealias GitComponent = LumiComponentGit.GitComponent
public typealias GitAccessCoordinator = LumiComponentGit.GitAccessCoordinator

// MARK: - Layout Component Types

public typealias LayoutComponent = LumiComponentLayout.LayoutComponent
public typealias LayoutState = LumiComponentLayout.LayoutState
public typealias LayoutEventPayload = LumiComponentLayout.LayoutEventPayload

// MARK: - Logo Component Types

public typealias LogoComponent = LumiComponentLayout.LogoComponent
public typealias LogoItem = LumiComponentLayout.LogoItem
public typealias LogoScene = LumiComponentLayout.LogoScene

// MARK: - Chat Section Types

public typealias LumiChatSectionLayout = LumiComponentLayout.LumiChatSectionLayout
public typealias LumiChatSectionPlacement = LumiComponentLayout.LumiChatSectionPlacement
public typealias LumiChatSectionItem = LumiComponentLayout.LumiChatSectionItem
public typealias LumiChatSectionToolbarBarItem = LumiComponentLayout.LumiChatSectionToolbarBarItem
public typealias LumiChatSectionHeaderItem = LumiComponentLayout.LumiChatSectionHeaderItem
public typealias LumiChatSectionToolbarPlacement = LumiComponentLayout.LumiChatSectionToolbarPlacement
public typealias LumiChatSectionToolbarItem = LumiComponentLayout.LumiChatSectionToolbarItem

// MARK: - Split Divider Types

public typealias DividerClamp = LumiComponentLayout.DividerClamp
public typealias DividerDragClassification = LumiComponentLayout.DividerDragClassification
public typealias SplitDividerAccess = LumiComponentLayout.SplitDividerAccess
public typealias SplitDividerRole = LumiComponentLayout.SplitDividerRole

// 类型经 typealias 导出；`Notification.Name` / `View` 扩展无法 typealias，
// 需要 `@_exported` 让只 import LumiCoreKit 的下游模块（插件）继续可见，
// 与这些代码此前直接内嵌在 LumiCoreKit 时的可见性保持一致。
@_exported import LumiComponentProject

// MARK: - Project Component Types

public typealias ProjectComponent = LumiComponentProject.ProjectComponent
public typealias ProjectState = LumiComponentProject.ProjectState
public typealias ProjectEntry = LumiComponentProject.ProjectEntry
public typealias ProjectLanguageDetector = LumiComponentProject.ProjectLanguageDetector

@_exported import LumiComponentStorage

// MARK: - Storage Component Types

public typealias StorageComponent = LumiComponentStorage.StorageComponent
