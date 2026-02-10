import Foundation

struct DockerImage: Identifiable, Codable, Hashable {
    var id: String { imageID }
    
    // Rename ID to imageID to avoid conflict with Identifiable.ID (which defaults to ID if it exists)
    // Map JSON key "ID" to this property
    let imageID: String
    let Repository: String
    let Tag: String
    let CreatedAt: String
    let CreatedSince: String
    let Size: String
    let VirtualSize: String
    let Digest: String
    
    enum CodingKeys: String, CodingKey {
        case imageID = "ID"
        case Repository, Tag, CreatedAt, CreatedSince, Size, VirtualSize, Digest
    }
    
    // Helper properties
    var name: String {
        if Repository == "<none>" { return imageID.prefix(12).description }
        return "\(Repository):\(Tag)"
    }
    
    var shortID: String {
        return String(imageID.replacingOccurrences(of: "sha256:", with: "").prefix(12))
    }
    
    var sizeBytes: Int64 {
        return 0 
    }
}

struct DockerImageHistory: Identifiable, Codable {
    var id: String { String(Created) + CreatedBy }
    
    // Note: Docker's JSON output format for history might have different key names or timestamp formats
    // Created is often a Unix timestamp integer in `docker images`, but let's check history format.
    // If it fails, we might need flexible decoding.
    let Created: Int64
    let CreatedBy: String
    let Size: String
    let Comment: String
}

struct DockerInspect: Codable {
    let Id: String
    let RepoTags: [String]?
    let Architecture: String
    let Os: String
    let Size: Int64?
    let VirtualSize: Int64?
    let Author: String?
    let Config: DockerConfig?
}

struct DockerConfig: Codable {
    let Env: [String]?
    let Cmd: [String]?
    let Image: String?
    let WorkingDir: String?
    let Entrypoint: [String]?
}
