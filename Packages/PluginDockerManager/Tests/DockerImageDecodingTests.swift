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

@Suite("Docker history decoding")
struct DockerHistoryDecodingTests {
    /// 真实 `docker history --format '{{json .}}'` 行：CreatedAt/CreatedSince
    /// 为字符串，没有整数 Created 字段（#248）。
    private let realHistoryLine = """
    {"Comment":"","CreatedAt":"2026-01-01 00:00:00 +0000 UTC","CreatedBy":"/bin/sh -c #(nop) ADD file:abc123 in / ","CreatedSince":"2 months ago","ID":"<missing>","Size":"12.3MB"}
    """

    private let secondHistoryLine = """
    {"Comment":"","CreatedAt":"2026-01-02 00:00:00 +0000 UTC","CreatedBy":"/bin/sh -c #(nop) CMD nginx","CreatedSince":"2 months ago","ID":"<missing>","Size":"0B"}
    """

    @Test("真实 docker history JSON 必须可解码，不得静默返回空历史")
    func decodesRealHistoryLine() throws {
        let decoded = try JSONDecoder().decode(DockerImageHistory.self, from: Data(realHistoryLine.utf8))
        #expect(decoded.CreatedAt == "2026-01-01 00:00:00 +0000 UTC")
        #expect(decoded.CreatedSince == "2 months ago")
        #expect(decoded.CreatedBy.contains("ADD file"))
        #expect(decoded.Size == "12.3MB")
        #expect(decoded.Comment == "")
    }

    @Test("多层历史逐行解码并保序")
    func decodesMultiLayerHistory() throws {
        let output = realHistoryLine + "\n" + secondHistoryLine
        let history = try DockerService.decodeHistory(from: output)

        #expect(history.count == 2)
        #expect(history.first?.CreatedBy.contains("ADD file") == true)
        #expect(history.last?.CreatedBy.contains("CMD nginx") == true)
    }

    @Test("全部历史行解析失败时抛错，而不是返回成功的空历史")
    func allInvalidHistoryLinesThrow() {
        #expect(throws: DockerError.self) {
            try DockerService.decodeHistory(from: #"{"CreatedBy":"RUN"}"#)
        }
    }

    @Test("部分历史行解析失败时保留成功行")
    func partialHistoryFailureKeepsValid() throws {
        let output = realHistoryLine + "\n" + #"{"CreatedBy":"RUN"}"#
        let history = try DockerService.decodeHistory(from: output)

        #expect(history.count == 1)
        #expect(history.first?.CreatedBy.contains("ADD file") == true)
    }

    @Test("空历史输出返回空列表")
    func emptyHistoryOutputReturnsEmpty() throws {
        let history = try DockerService.decodeHistory(from: "")

        #expect(history.isEmpty)
    }
}
