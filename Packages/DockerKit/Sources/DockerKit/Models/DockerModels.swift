import Foundation

// MARK: - Error Types

public enum DockerError: Error, LocalizedError, Sendable {
    case commandFailed(String)
    case parsingFailed(String)
    case dockerNotFound

    public var errorDescription: String? {
        switch self {
        case .commandFailed(let msg):
            return "Docker command failed: \(msg)"
        case .parsingFailed(let msg):
            return "Failed to parse Docker output: \(msg)"
        case .dockerNotFound:
            return "Docker executable not found. Please ensure Docker is installed and in your PATH."
        }
    }
}

// MARK: - Image Models

/// Represents a Docker image with metadata from `docker images`
public struct DockerImage: Identifiable, Codable, Hashable, Sendable {
    public var id: String { imageID }

    public let imageID: String
    public let repository: String
    public let tag: String
    public let createdAt: String
    public let createdSince: String
    public let size: String
    public let virtualSize: String
    public let digest: String

    public init(
        imageID: String,
        repository: String,
        tag: String,
        createdAt: String,
        createdSince: String,
        size: String,
        virtualSize: String,
        digest: String
    ) {
        self.imageID = imageID
        self.repository = repository
        self.tag = tag
        self.createdAt = createdAt
        self.createdSince = createdSince
        self.size = size
        self.virtualSize = virtualSize
        self.digest = digest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.imageID = try container.decode(String.self, forKey: .imageID)
        self.repository = try container.decode(String.self, forKey: .repository)
        self.tag = try container.decode(String.self, forKey: .tag)
        self.createdAt = try container.decode(String.self, forKey: .createdAt)
        self.createdSince = try container.decode(String.self, forKey: .createdSince)
        self.size = try container.decode(String.self, forKey: .size)
        self.virtualSize = try container.decode(String.self, forKey: .virtualSize)
        self.digest = try container.decodeIfPresent(String.self, forKey: .digest) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(imageID, forKey: .imageID)
        try container.encode(repository, forKey: .repository)
        try container.encode(tag, forKey: .tag)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(createdSince, forKey: .createdSince)
        try container.encode(size, forKey: .size)
        try container.encode(virtualSize, forKey: .virtualSize)
        try container.encode(digest, forKey: .digest)
    }

    public enum CodingKeys: String, CodingKey {
        case imageID = "ID"
        case repository = "Repository"
        case tag = "Tag"
        case createdAt = "CreatedAt"
        case createdSince = "CreatedSince"
        case size = "Size"
        case virtualSize = "VirtualSize"
        case digest = "Digest"
    }

    // MARK: - Helper Properties

    /// Display name: "repository:tag" or short ID if unnamed
    public var name: String {
        if repository == "<none>" {
            return shortID
        }
        return "\(repository):\(tag)"
    }

    /// Shortened ID (first 12 chars, without sha256: prefix)
    public var shortID: String {
        return String(imageID.replacingOccurrences(of: "sha256:", with: "").prefix(12))
    }

    /// Size in bytes (requires parsing size string, placeholder for now)
    public var sizeBytes: Int64 {
        return 0 // TODO: Implement size string parsing
    }
}

/// Image history entry from `docker history`
public struct DockerImageHistory: Identifiable, Codable, Sendable {
    public var id: String { String(Created) + CreatedBy }

    public let Created: Int64
    public let CreatedBy: String
    public let Size: String
    public let Comment: String

    public init(Created: Int64, CreatedBy: String, Size: String, Comment: String) {
        self.Created = Created
        self.CreatedBy = CreatedBy
        self.Size = Size
        self.Comment = Comment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.Created = try container.decode(Int64.self, forKey: .Created)
        self.CreatedBy = try container.decode(String.self, forKey: .CreatedBy)
        // Docker history --format outputs Size as Int64, but we store as String
        if let sizeInt = try? container.decode(Int64.self, forKey: .Size) {
            self.Size = ByteCountFormatter.string(fromByteCount: sizeInt, countStyle: .binary)
        } else {
            self.Size = try container.decode(String.self, forKey: .Size)
        }
        self.Comment = try container.decode(String.self, forKey: .Comment)
    }
}

/// Detailed inspection data from `docker inspect`
public struct DockerInspect: Codable, Sendable {
    public let Id: String
    public let RepoTags: [String]?
    public let Architecture: String
    public let Os: String
    public let Size: Int64?
    public let VirtualSize: Int64?
    public let Author: String?
    public let Config: DockerConfig?

    public init(
        Id: String,
        RepoTags: [String]?,
        Architecture: String,
        Os: String,
        Size: Int64?,
        VirtualSize: Int64?,
        Author: String?,
        Config: DockerConfig?
    ) {
        self.Id = Id
        self.RepoTags = RepoTags
        self.Architecture = Architecture
        self.Os = Os
        self.Size = Size
        self.VirtualSize = VirtualSize
        self.Author = Author
        self.Config = Config
    }
}

/// Docker image configuration
public struct DockerConfig: Codable, Sendable {
    public let Env: [String]?
    public let Cmd: [String]?
    public let Image: String?
    public let WorkingDir: String?
    public let Entrypoint: [String]?

    public init(
        Env: [String]?,
        Cmd: [String]?,
        Image: String?,
        WorkingDir: String?,
        Entrypoint: [String]?
    ) {
        self.Env = Env
        self.Cmd = Cmd
        self.Image = Image
        self.WorkingDir = WorkingDir
        self.Entrypoint = Entrypoint
    }
}
