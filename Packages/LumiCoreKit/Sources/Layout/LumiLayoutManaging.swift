import Foundation

/// 布局持久化能力协议
/// 由插件实现，提供布局数据的读写能力
public protocol LumiLayoutPersistence: Sendable {
    // MARK: - View Container
    
    /// 加载已保存的视图容器 ID
    func loadActiveViewContainerID() -> String?
    
    /// 保存视图容器 ID
    func saveActiveViewContainerID(_ id: String?)
    
    // MARK: - Sidebar Visibility
    
    /// 加载右侧栏可见性
    func loadRightSidebarVisible() -> Bool?
    
    /// 保存右侧栏可见性
    func saveRightSidebarVisible(_ visible: Bool)
    
    /// 加载底部面板可见性
    func loadBottomPanelVisible() -> Bool?
    
    /// 保存底部面板可见性
    func saveBottomPanelVisible(_ visible: Bool)
    
    // MARK: - Split Dimensions
    
    /// 加载分栏尺寸
    func loadSplitDimension(forKey key: String) -> Double?
    
    /// 保存分栏尺寸
    func saveSplitDimension(_ value: Double, forKey key: String)
    
    /// 加载全部分栏尺寸
    func loadSplitDimensions() -> [String: Double]
    
    // MARK: - Layout Ratios
    
    /// 加载布局比例
    func loadLayoutRatios() -> [String: Double]
    
    /// 保存布局比例
    func saveLayoutRatios(_ ratios: [String: Double])
    
    // MARK: - Panel Visibility
    
    /// 加载编辑器底部面板高度
    func loadEditorBottomPanelHeight() -> Double?
    
    /// 保存编辑器底部面板高度
    func saveEditorBottomPanelHeight(_ height: Double)
    
    /// 加载内容面板可见性
    func loadContentPanelVisible() -> Bool?
    
    /// 保存内容面板可见性
    func saveContentPanelVisible(_ visible: Bool)
    
    /// 加载编辑器可见性
    func loadEditorVisible() -> Bool?
    
    /// 保存编辑器可见性
    func saveEditorVisible(_ visible: Bool)
    
    /// 加载 Rail 可见性
    func loadRailVisible() -> Bool?
    
    /// 保存 Rail 可见性
    func saveRailVisible(_ visible: Bool)
}

/// 布局管理器协议
/// 定义布局状态的读写接口
public protocol LumiLayoutManaging: Sendable {
    /// 布局持久化实现
    var persistence: LumiLayoutPersistence { get }
    
    /// 恢复持久化的布局状态
    func restorePersistedState()
}

// MARK: - Default Implementation for LumiLayoutStateStore

import Combine

/// LumiCoreKit 提供的默认布局状态存储（内存中）
/// 需要配合 LumiLayoutPersistence 使用
@MainActor
public final class LumiLayoutStateStore: ObservableObject {
    public static let shared = LumiLayoutStateStore()
    
    @Published public var activeViewContainerID: String?
    @Published public var chatSectionVisible: Bool = true
    @Published public var bottomPanelVisible: Bool = true
    
    private var persistence: (any LumiLayoutPersistence)?
    private static var didRestore = false
    
    private init() {}
    
    /// 注入持久化实现
    public func injectPersistence(_ persistence: any LumiLayoutPersistence) {
        self.persistence = persistence
    }
    
    public func activateViewContainer(id: String) {
        activeViewContainerID = id
    }
    
    /// 从持久化恢复状态（幂等调用）
    public static func restorePersistedStateIfNeeded() {
        guard !didRestore else { return }
        didRestore = true
        shared.restoreFromPersistence()
    }
    
    /// 从持久化恢复状态
    public func restoreFromPersistence() {
        guard let persistence else { return }
        
        if let id = persistence.loadActiveViewContainerID() {
            activeViewContainerID = id
        }
        if let visible = persistence.loadRightSidebarVisible() {
            chatSectionVisible = visible
        }
        if let visible = persistence.loadBottomPanelVisible() {
            bottomPanelVisible = visible
        }
    }
    
    /// 同步状态到持久化（当状态变化时调用）
    public func syncToPersistence() {
        guard let persistence else { return }
        
        persistence.saveActiveViewContainerID(activeViewContainerID)
        persistence.saveRightSidebarVisible(chatSectionVisible)
        persistence.saveBottomPanelVisible(bottomPanelVisible)
    }
}
