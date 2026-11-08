@testable import DockerManagerPlugin
import Foundation
import Testing

@Suite("Docker image decoding")
struct DockerImageDecodingTests {
    /// 新版 Docker CLI 的行：有 Size，但没有 VirtualSize。
    private let modernImageLine = """
    {"Containers":"N/A","CreatedAt":"2026-01-01 00:00:00 +0000","CreatedSince":"1 day ago","Digest":"<none>","ID":"sha256:0123456789abcdef","Repository":"nginx","SharedSize":"N/A","Size":"187MB","Tag":"latest","UniqueSize":"N/A"}
    """

    @Test("缺少 VirtualSize 时回退到 Size，而不是丢弃整行")
    func missingVirtualSizeFallsBackToSize() throws {
        let images = try DockerService.decodeImages(from: modernImageLine)

        #expect(images.count == 1)
        #expect(images.first?.size == "187MB")
        #expect(images.first?.virtualSize == "187MB")
    }

    @Test("全部行解析失败时抛错，而不是返回成功的空列表")
    func allInvalidLinesThrow() {
        #expect(throws: DockerError.self) {
            try DockerService.decodeImages(from: #"{"ID":"sha256:broken"}"#)
        }
    }

    @Test("部分行解析失败时保留成功行")
    func partialFailureKeepsValidImages() throws {
        let output = modernImageLine + "\n" + #"{"ID":"sha256:broken"}"#
        let images = try DockerService.decodeImages(from: output)

        #expect(images.count == 1)
        #expect(images.first?.repository == "nginx")
    }

    @Test("空输出返回空列表")
    func emptyOutputReturnsEmptyList() throws {
        let images = try DockerService.decodeImages(from: "")

        #expect(images.isEmpty)
    }
}
