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

// MARK: - LockedDataBuffer Tests

struct LockedDataBufferTests {
    @Test
    func appendAndSnapshotWork() {
        let buffer = LockedDataBuffer()
        
        buffer.append(Data("hello".utf8))
        buffer.append(Data(" world".utf8))
        
        let snapshot = buffer.snapshot()
        let string = String(data: snapshot, encoding: .utf8)
        
        #expect(string == "hello world")
    }
    
    @Test
    func snapshotIsIsolated() {
        let buffer = LockedDataBuffer()
        
        buffer.append(Data("test".utf8))
        
        let snapshot1 = buffer.snapshot()
        buffer.append(Data(" more".utf8))
        let snapshot2 = buffer.snapshot()
        
        let string1 = String(data: snapshot1, encoding: .utf8)
        let string2 = String(data: snapshot2, encoding: .utf8)
        
        #expect(string1 == "test")
        #expect(string2 == "test more")
    }
}
