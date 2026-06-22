import DownloadKit
import Testing

@Suite("DownloadError Tests")
struct DownloadErrorTests {
    
    @Test("错误描述不为空")
    func errorDescriptionsNotEmpty() {
        let errors: [DownloadError] = [
            .invalidURL("http://invalid"),
            .httpError(404),
            .networkError("timeout"),
            .fileNotFound("/path/to/file"),
            .sizeMismatch(expected: 100, actual: 50),
            .emptyFile("/path/to/empty"),
            .cannotCreateDirectory("/path/to/dir"),
            .cannotWriteFile("/path/to/file"),
            .cancelled,
            .unknown("something went wrong")
        ]
        
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
    
    @Test("错误相等性")
    func errorEquality() {
        #expect(DownloadError.httpError(404) == DownloadError.httpError(404))
        #expect(DownloadError.httpError(404) != DownloadError.httpError(500))
        #expect(DownloadError.cancelled == DownloadError.cancelled)
        #expect(DownloadError.invalidURL("a") == DownloadError.invalidURL("a"))
        #expect(DownloadError.invalidURL("a") != DownloadError.invalidURL("b"))
    }
}
