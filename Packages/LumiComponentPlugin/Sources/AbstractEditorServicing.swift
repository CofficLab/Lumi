import Foundation

/// 抽象的编辑器服务协议
/// 
/// 定义在 LumiCoreKit 中，避免循环依赖。
/// EditorService 中的具体实现应遵循此协议。
/// 
/// ## 架构说明
/// 
/// LumiCoreKit 不能依赖 EditorService（会导致循环依赖：LumiCoreKit → EditorService → LumiUI → LumiCoreKit）
/// 因此这里定义一个抽象协议，由应用层在初始化时注册具体实现。
@MainActor
public protocol AbstractEditorServicing: AnyObject {
    /// 当前项目路径提供者
    var currentProjectPathProvider: (() -> String)? { get set }
    
    /// 重新安装编辑器扩展
    func reinstallExtensions()
}
