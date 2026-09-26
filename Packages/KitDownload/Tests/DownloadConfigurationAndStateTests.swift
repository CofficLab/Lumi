import Foundation
import Testing
@testable import KitDownload

@Suite("DownloadManager.Configuration 默认值")
struct DownloadConfigurationDefaultsTests {

    @Test("默认配置：并发 3、超时 3600、启用续传、不限速")
    func defaults() {
        let config = DownloadManager.Configuration()
        #expect(config.maxConcurrentDownloads == 3)
        #expect(config.timeoutInterval == 3600)
        #expect(config.enableResume == true)
        #expect(config.maxBytesPerSecond == nil)
        // 默认下载目录落到临时目录下的 KitDownload
        #expect(config.downloadDirectory.lastPathComponent == "KitDownload")
    }

    @Test("自定义配置覆盖默认值")
    func customOverrides() {
        let dir = URL(fileURLWithPath: "/tmp/lumi-dl-test")
        let config = DownloadManager.Configuration(
            downloadDirectory: dir,
            maxConcurrentDownloads: 7,
            timeoutInterval: 120,
            enableResume: false,
            maxBytesPerSecond: 1024
        )
        #expect(config.downloadDirectory == dir)
        #expect(config.maxConcurrentDownloads == 7)
        #expect(config.timeoutInterval == 120)
        #expect(config.enableResume == false)
        #expect(config.maxBytesPerSecond == 1024)
    }
}

@Suite("DownloadTaskState.isFinal")
struct DownloadTaskStateIsFinalTests {

    @Test("非终态：pending / downloading")
    func nonFinal() {
        #expect(DownloadTaskState.pending.isFinal == false)
        let progress = DownloadProgress(downloadedBytes: 10, totalBytes: 100, bytesPerSecond: 0)
        #expect(DownloadTaskState.downloading(progress: progress).isFinal == false)
    }

    @Test("终态：completed / failed / cancelled")
    func finalStates() {
        #expect(DownloadTaskState.completed.isFinal == true)
        #expect(DownloadTaskState.failed(.cancelled).isFinal == true)
        #expect(DownloadTaskState.failed(.httpError(500)).isFinal == true)
        #expect(DownloadTaskState.cancelled.isFinal == true)
    }
}
