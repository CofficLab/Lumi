import DownloadKit
import Testing
import Foundation

@Suite("DownloadTask Tests")
struct DownloadTaskTests {
    
    @Test("任务创建")
    func taskCreation() async throws {
        let url = URL(string: "https://example.com/file.txt")!
        let destination = URL(fileURLWithPath: "/tmp/file.txt")
        
        let task = DownloadTask(
            url: url,
            destination: destination,
            expectedSize: 1024
        )
        
        #expect(task.url == url)
        #expect(task.destination == destination)
        #expect(task.expectedSize == 1024)
        #expect(!task.id.isEmpty)
    }
    
    @Test("未完成文件路径正确")
    func incompleteURL() async throws {
        let destination = URL(fileURLWithPath: "/tmp/file.txt")
        let task = DownloadTask(
            url: URL(string: "https://example.com/file.txt")!,
            destination: destination
        )
        
        #expect(task.incompleteURL.path.hasSuffix(".incomplete"))
        #expect(task.incompleteURL.path == "/tmp/file.txt.incomplete")
    }
    
    @Test("自定义 ID")
    func customId() async throws {
        let task = DownloadTask(
            id: "custom-id",
            url: URL(string: "https://example.com/file.txt")!,
            destination: URL(fileURLWithPath: "/tmp/file.txt")
        )
        
        #expect(task.id == "custom-id")
    }
    
    @Test("自定义请求头")
    func customHeaders() async throws {
        let task = DownloadTask(
            url: URL(string: "https://example.com/file.txt")!,
            destination: URL(fileURLWithPath: "/tmp/file.txt"),
            headers: ["Authorization": "Bearer token"]
        )
        
        #expect(task.headers["Authorization"] == "Bearer token")
    }
    
    @Test("任务状态相等性")
    func taskStateEquality() {
        #expect(DownloadTaskState.pending == DownloadTaskState.pending)
        #expect(DownloadTaskState.completed == DownloadTaskState.completed)
        #expect(DownloadTaskState.cancelled == DownloadTaskState.cancelled)
        #expect(DownloadTaskState.pending != DownloadTaskState.completed)
        
        let progress = DownloadProgress(downloadedBytes: 50, totalBytes: 100)
        #expect(DownloadTaskState.downloading(progress: progress) == DownloadTaskState.downloading(progress: progress))
        #expect(DownloadTaskState.failed(.cancelled) == DownloadTaskState.failed(.cancelled))
    }
}
