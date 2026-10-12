import Foundation

/// 场景中的组件类型标签。
public enum ComponentKind: String, Codable, Equatable, Sendable {
    case profile
    case connector
}

/// 场景中的统一组件包装，用于 UI 展示、BOM 汇总与场景节点映射。
public enum CADComponent: Codable, Equatable, Identifiable, Sendable {
    case profile(ProfileInstance)
    case connector(ConnectorInstance)

    public var id: String {
        switch self {
        case .profile(let instance): return instance.id
        case .connector(let instance): return instance.id
        }
    }

    public var kind: ComponentKind {
        switch self {
        case .profile: return .profile
        case .connector: return .connector
        }
    }

    public var transform: Transform3D {
        get {
            switch self {
            case .profile(let instance): return instance.transform
            case .connector(let instance): return instance.transform
            }
        }
        set {
            switch self {
            case .profile(var instance):
                instance.transform = newValue
                self = .profile(instance)
            case .connector(var instance):
                instance.transform = newValue
                self = .connector(instance)
            }
        }
    }

    /// 显示名称（需配合目录解析规格名；未解析时回退为零件号）。
    public func displayName(library: ComponentLibrary) -> String {
        switch self {
        case .profile(let instance):
            return library.profileSpec(id: instance.profileId)?.name ?? instance.profileId
        case .connector(let instance):
            return library.connectorSpec(id: instance.connectorId)?.name ?? instance.connectorId
        }
    }
}
