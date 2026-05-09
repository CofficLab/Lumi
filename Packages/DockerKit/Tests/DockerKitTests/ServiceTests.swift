import Foundation
import Testing
@testable import DockerKit

// NOTE: Full integration tests require actual Docker installation
// These tests provide a framework for mocking Docker CLI output

// MARK: - Service Tests

struct DockerServiceTests {
    @Test
    func serviceIsSingleton() {
        let a = DockerService.shared
        let b = DockerService.shared
        #expect(a === b)
    }
}

// MARK: - Model Decoding Tests

struct DockerCLIOutputParsingTests {
    @Test
    func parseListImagesOutput() throws {
        // Simulate Docker CLI output for listing images
        let mockOutput = """
        {"ID":"sha256:abc123","Repository":"ubuntu","Tag":"20.04","CreatedAt":"2024-01-01 12:00:00 +0000","CreatedSince":"2 weeks ago","Size":"100MB","VirtualSize":"100MB","Digest":"sha256:def456"}
        {"ID":"sha256:xyz789","Repository":"nginx","Tag":"latest","CreatedAt":"2024-01-02 12:00:00 +0000","CreatedSince":"1 week ago","Size":"50MB","VirtualSize":"50MB","Digest":"sha256:ghi012"}
        """
        
        let lines = mockOutput.components(separatedBy: .newlines)
        var images: [DockerImage] = []
        let decoder = JSONDecoder()
        
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8) {
                let image = try decoder.decode(DockerImage.self, from: data)
                images.append(image)
            }
        }
        
        #expect(images.count == 2)
        #expect(images[0].repository == "ubuntu")
        #expect(images[1].repository == "nginx")
    }
    
    @Test
    func parseInspectOutput() throws {
        let mockOutput = """
        [{
            "Id": "sha256:abc123",
            "RepoTags": ["ubuntu:20.04"],
            "Architecture": "amd64",
            "Os": "linux",
            "Size": 100000000,
            "VirtualSize": 100000000,
            "Author": "test",
            "Config": {
                "Env": ["PATH=/usr/local/sbin:/usr/local/bin"],
                "Cmd": ["/bin/bash"],
                "Image": "ubuntu",
                "WorkingDir": "/root",
                "Entrypoint": null
            }
        }]
        """
        
        let decoder = JSONDecoder()
        let results = try decoder.decode([DockerInspect].self, from: mockOutput.data(using: .utf8)!)
        
        #expect(results.count == 1)
        #expect(results[0].Id == "sha256:abc123")
        #expect(results[0].Architecture == "amd64")
        #expect(results[0].Config?.Env?.first == "PATH=/usr/local/sbin:/usr/local/bin")
    }
    
    @Test
    func parseHistoryOutput() throws {
        let mockOutput = """
        {"CreatedBy":"/bin/bash","Size":0,"Comment":"","Created":1234567890}
        {"CreatedBy":"apt-get update","Size":1024,"Comment":"Update packages","Created":1234567891}
        """
        
        let lines = mockOutput.components(separatedBy: .newlines)
        var history: [DockerImageHistory] = []
        let decoder = JSONDecoder()
        
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8) {
                let item = try decoder.decode(DockerImageHistory.self, from: data)
                history.append(item)
            }
        }
        
        #expect(history.count == 2)
        #expect(history[0].CreatedBy == "/bin/bash")
        #expect(history[1].Comment == "Update packages")
    }
    
    @Test
    func handleEmptyListOutput() throws {
        let mockOutput = ""
        let lines = mockOutput.components(separatedBy: .newlines)
        
        var images: [DockerImage] = []
        let decoder = JSONDecoder()
        
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8) {
                let image = try decoder.decode(DockerImage.self, from: data)
                images.append(image)
            }
        }
        
        #expect(images.isEmpty)
    }
    
    @Test
    func handleMalformedLinesGracefully() throws {
        let mockOutput = """
        {"ID":"sha256:abc123","Repository":"ubuntu","Tag":"20.04","CreatedAt":"2024-01-01","CreatedSince":"2 weeks ago","Size":"100MB","VirtualSize":"100MB","Digest":"sha256:def456"}
        this is not valid json
        {"ID":"sha256:xyz789","Repository":"nginx","Tag":"latest","CreatedAt":"2024-01-02","CreatedSince":"1 week ago","Size":"50MB","VirtualSize":"50MB","Digest":"sha256:ghi012"}
        """
        
        let lines = mockOutput.components(separatedBy: .newlines)
        var images: [DockerImage] = []
        let decoder = JSONDecoder()
        
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8) {
                do {
                    let image = try decoder.decode(DockerImage.self, from: data)
                    images.append(image)
                } catch {
                    // Skip malformed lines
                }
            }
        }
        
        // Should successfully parse 2 valid images, skip 1 invalid
        #expect(images.count == 2)
        #expect(images[0].repository == "ubuntu")
        #expect(images[1].repository == "nginx")
    }
}
