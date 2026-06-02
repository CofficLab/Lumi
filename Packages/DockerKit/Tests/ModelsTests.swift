import Foundation
import Testing
@testable import DockerKit

// MARK: - Model Tests

struct DockerImageTests {
    @Test
    func imageNameWithRepository() {
        let image = DockerImage(
            imageID: "sha256:abc123",
            repository: "ubuntu",
            tag: "20.04",
            createdAt: "2024-01-01",
            createdSince: "2 weeks ago",
            size: "100MB",
            virtualSize: "100MB",
            digest: "sha256:def456"
        )
        
        #expect(image.name == "ubuntu:20.04")
        #expect(image.shortID == "abc123")
    }
    
    @Test
    func imageNameWithoutRepository() {
        let image = DockerImage(
            imageID: "sha256:abc123def456",
            repository: "<none>",
            tag: "<none>",
            createdAt: "2024-01-01",
            createdSince: "2 weeks ago",
            size: "100MB",
            virtualSize: "100MB",
            digest: ""
        )
        
        #expect(image.name == "abc123def456")
        #expect(image.shortID == "abc123def456")
    }
    
    @Test
    func shortIDRemovesSha256Prefix() {
        let image = DockerImage(
            imageID: "sha256:a1b2c3d4e5f6",
            repository: "test",
            tag: "latest",
            createdAt: "",
            createdSince: "",
            size: "",
            virtualSize: "",
            digest: ""
        )
        
        #expect(image.shortID == "a1b2c3d4e5f6")
    }

    @Test
    func parsesDockerSizeStringsToBytes() {
        #expect(DockerImage.parseSizeBytes("0B") == 0)
        #expect(DockerImage.parseSizeBytes("900B") == 900)
        #expect(DockerImage.parseSizeBytes("1kB") == 1_000)
        #expect(DockerImage.parseSizeBytes("12.5MB") == 12_500_000)
        #expect(DockerImage.parseSizeBytes("1.2GB") == 1_200_000_000)
        #expect(DockerImage.parseSizeBytes("2MiB") == 2_097_152)
        #expect(DockerImage.parseSizeBytes("invalid") == 0)
    }

    @Test
    func imageSizeBytesUsesParsedSize() {
        let image = DockerImage(
            imageID: "sha256:abc123",
            repository: "ubuntu",
            tag: "20.04",
            createdAt: "2024-01-01",
            createdSince: "2 weeks ago",
            size: "1.2GB",
            virtualSize: "1.2GB",
            digest: ""
        )

        #expect(image.sizeBytes == 1_200_000_000)
    }
}

struct DockerErrorTests {
    @Test
    func errorDescriptions() {
        let error1 = DockerError.commandFailed("test error")
        #expect(error1.errorDescription == "Docker command failed: test error")
        
        let error2 = DockerError.parsingFailed("json error")
        #expect(error2.errorDescription == "Failed to parse Docker output: json error")
        
        let error3 = DockerError.dockerNotFound
        #expect(error3.errorDescription?.contains("Docker executable not found") == true)
    }
}

// MARK: - Coding Tests

struct DockerImageCodingTests {
    @Test
    func decodeDockerImageOutput() throws {
        let json = """
        {
            "ID": "sha256:abc123",
            "Repository": "ubuntu",
            "Tag": "20.04",
            "CreatedAt": "2024-01-01 12:00:00 +0000",
            "CreatedSince": "2 weeks ago",
            "Size": "100MB",
            "VirtualSize": "100MB",
            "Digest": "sha256:def456"
        }
        """
        
        let data = json.data(using: .utf8)!
        let image = try JSONDecoder().decode(DockerImage.self, from: data)
        
        #expect(image.imageID == "sha256:abc123")
        #expect(image.repository == "ubuntu")
        #expect(image.tag == "20.04")
    }
    
    @Test
    func decodeDockerImageWithoutDigest() throws {
        let json = """
        {
            "ID": "sha256:abc123",
            "Repository": "test",
            "Tag": "latest",
            "CreatedAt": "",
            "CreatedSince": "",
            "Size": "",
            "VirtualSize": ""
        }
        """
        
        let data = json.data(using: .utf8)!
        let image = try JSONDecoder().decode(DockerImage.self, from: data)
        
        #expect(image.digest == "")
    }
}
