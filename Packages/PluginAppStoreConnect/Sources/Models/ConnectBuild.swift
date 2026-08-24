import Foundation

/// App Store Connect `builds` 资源模型。
/// 代表通过 Xcode / Transporter 上传到 App Store Connect 的构建版本。
struct ConnectBuild: Identifiable, Equatable, Decodable {
    let id: String
    let version: String
    let uploadedDate: Date?
    let expirationDate: Date?
    let expired: Bool
    let minOsVersion: String?
    let processingState: String
    let usesNonExemptEncryption: Bool?

    /// 该构建对应的预发布版本号（通过 include=preReleaseVersion 注入，非 API 原始字段）
    var preReleaseVersionString: String?

    /// preReleaseVersion 关系资源 ID（解码自 relationships，用于与 included 匹配）
    let preReleaseVersionID: String?

    /// 处理完成且未过期的构建才能关联到 App Store 版本
    var isAssignable: Bool {
        !expired && processingState.uppercased() == "VALID"
    }

    /// 构建是否仍在 Apple 侧处理中
    var isProcessing: Bool {
        processingState.uppercased() == "PROCESSING"
    }

    /// 展示用标签：营销版本号 + 构建号，如 "1.2.0 (45)"
    var displayLabel: String {
        if let preReleaseVersionString, !preReleaseVersionString.isEmpty {
            return "\(preReleaseVersionString) (\(version))"
        }
        return version
    }

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }

    enum AttributeKeys: String, CodingKey {
        case version
        case uploadedDate
        case expirationDate
        case expired
        case minOsVersion
        case processingState
        case usesNonExemptEncryption
    }

    enum RelationshipKeys: String, CodingKey {
        case preReleaseVersion
    }

    init(
        id: String,
        version: String,
        uploadedDate: Date? = nil,
        expirationDate: Date? = nil,
        expired: Bool = false,
        minOsVersion: String? = nil,
        processingState: String = "PROCESSING",
        usesNonExemptEncryption: Bool? = nil,
        preReleaseVersionString: String? = nil,
        preReleaseVersionID: String? = nil
    ) {
        self.id = id
        self.version = version
        self.uploadedDate = uploadedDate
        self.expirationDate = expirationDate
        self.expired = expired
        self.minOsVersion = minOsVersion
        self.processingState = processingState
        self.usesNonExemptEncryption = usesNonExemptEncryption
        self.preReleaseVersionString = preReleaseVersionString
        self.preReleaseVersionID = preReleaseVersionID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        version = try attributes.decodeIfPresent(String.self, forKey: .version) ?? "-"
        uploadedDate = try attributes.decodeIfPresent(Date.self, forKey: .uploadedDate)
        expirationDate = try attributes.decodeIfPresent(Date.self, forKey: .expirationDate)
        expired = try attributes.decodeIfPresent(Bool.self, forKey: .expired) ?? false
        minOsVersion = try attributes.decodeIfPresent(String.self, forKey: .minOsVersion)
        processingState = try attributes.decodeIfPresent(String.self, forKey: .processingState) ?? "PROCESSING"
        usesNonExemptEncryption = try attributes.decodeIfPresent(Bool.self, forKey: .usesNonExemptEncryption)
        preReleaseVersionString = nil
        if let relationships = try? container.nestedContainer(keyedBy: RelationshipKeys.self, forKey: .relationships),
           let relationship = try? relationships.decode(AppStoreConnectRelationship.self, forKey: .preReleaseVersion) {
            preReleaseVersionID = relationship.data?.id
        } else {
            preReleaseVersionID = nil
        }
    }

    /// 返回注入了预发布版本号的新实例
    func withPreReleaseVersionString(_ value: String?) -> ConnectBuild {
        var copy = self
        copy.preReleaseVersionString = value
        return copy
    }
}

/// App Store Connect `preReleaseVersions` 资源（仅取 version / platform 字段）。
struct PreReleaseVersionResource: Decodable {
    let id: String
    let version: String?
    let platform: String?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case version
        case platform
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        version = try attributes.decodeIfPresent(String.self, forKey: .version)
        platform = try attributes.decodeIfPresent(String.self, forKey: .platform)
    }
}
