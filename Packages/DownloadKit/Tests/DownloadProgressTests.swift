import DownloadKit
import Testing

@Suite("DownloadProgress Tests")
struct DownloadProgressTests {
    
    @Test("默认进度为 0")
    func defaultProgress() {
        let progress = DownloadProgress()
        #expect(progress.downloadedBytes == 0)
        #expect(progress.totalBytes == nil)
        #expect(progress.fractionCompleted == 0.0)
        #expect(progress.percentLabel == "0%")
        #expect(progress.speedLabel == "")
    }
    
    @Test("进度百分比计算")
    func fractionCompletedCalculation() {
        let progress = DownloadProgress(downloadedBytes: 50, totalBytes: 100)
        #expect(progress.fractionCompleted == 0.5)
        #expect(progress.percentLabel == "50%")
    }
    
    @Test("总字节数为 0 时进度为 0")
    func zeroTotalBytes() {
        let progress = DownloadProgress(downloadedBytes: 50, totalBytes: 0)
        #expect(progress.fractionCompleted == 0.0)
    }
    
    @Test("总字节数为 nil 时进度为 0")
    func nilTotalBytes() {
        let progress = DownloadProgress(downloadedBytes: 50, totalBytes: nil)
        #expect(progress.fractionCompleted == 0.0)
    }
    
    @Test("速度标签格式正确")
    func speedLabelFormatting() {
        let progress = DownloadProgress(bytesPerSecond: 1024 * 1024) // 1 MB/s
        #expect(progress.speedLabel.contains("MB") || progress.speedLabel.contains("MB"))
    }
    
    @Test("速度为 0 时标签为空")
    func zeroSpeedLabel() {
        let progress = DownloadProgress(bytesPerSecond: 0)
        #expect(progress.speedLabel == "")
    }
    
    @Test("进度相等性")
    func progressEquality() {
        let p1 = DownloadProgress(downloadedBytes: 100, totalBytes: 200)
        let p2 = DownloadProgress(downloadedBytes: 100, totalBytes: 200)
        let p3 = DownloadProgress(downloadedBytes: 50, totalBytes: 200)
        
        #expect(p1 == p2)
        #expect(p1 != p3)
    }
    
    @Test("文件进度计算")
    func fileProgress() {
        let progress = DownloadProgress(
            downloadedFiles: 3,
            totalFiles: 10
        )
        #expect(progress.downloadedFiles == 3)
        #expect(progress.totalFiles == 10)
    }
}
