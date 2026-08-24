import Foundation
import SwiftData

/// 应用缓存项 - SwiftData 模型
@Model
final class AppCacheItem {
    @Attribute(.unique) var bundlePath: String
    var lastModified: TimeInterval
    var name: String
    var identifier: String?
    var version: String?
    var iconFileName: String?
    var size: Int64

    init(
        bundlePath: String,
        lastModified: TimeInterval,
        name: String,
        identifier: String?,
        version: String?,
        iconFileName: String?,
        size: Int64
    ) {
        self.bundlePath = bundlePath
        self.lastModified = lastModified
        self.name = name
        self.identifier = identifier
        self.version = version
        self.iconFileName = iconFileName
        self.size = size
    }

    /// 转为 DTO（供 AppService 使用）
    func toDTO() -> AppCacheItemDTO {
        AppCacheItemDTO(
            bundlePath: bundlePath,
            lastModified: lastModified,
            name: name,
            identifier: identifier,
            version: version,
            iconFileName: iconFileName,
            size: size
        )
    }
}

/// 缓存项 DTO（非持久化，用于返回值）
struct AppCacheItemDTO {
    let bundlePath: String
    let lastModified: TimeInterval
    let name: String
    let identifier: String?
    let version: String?
    let iconFileName: String?
    let size: Int64
}
