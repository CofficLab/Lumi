import Foundation
import Testing
@testable import ScreenRecorderPlugin

@Suite("RecordingFileWriter")
struct RecordingFileWriterTests {

    @Test("tempURL 落在 tmp 子目录且为 mp4")
    func tempURLShape() {
        let dir = URL(fileURLWithPath: "/tmp/lumi-rec-test")
        let url = RecordingFileWriter.tempURL(for: UUID(), in: dir)
        #expect(url.pathExtension == "mp4")
        #expect(url.deletingLastPathComponent().lastPathComponent == "tmp")
    }

    @Test("finalize 移动文件并按冲突追加序号")
    func finalizeConflict() async throws {
        let workdir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workdir) }

        let src1 = workdir.appendingPathComponent("src1.mp4")
        try Data("aaa".utf8).write(to: src1)
        let out1 = try await RecordingFileWriter.finalize(tempURL: src1, to: workdir, filename: "clip")
        #expect(out1.lastPathComponent == "clip.mp4")
        #expect(!FileManager.default.fileExists(atPath: src1.path))
        #expect(FileManager.default.fileExists(atPath: out1.path))

        let src2 = workdir.appendingPathComponent("src2.mp4")
        try Data("bbb".utf8).write(to: src2)
        let out2 = try await RecordingFileWriter.finalize(tempURL: src2, to: workdir, filename: "clip")
        #expect(out2.lastPathComponent == "clip-2.mp4")
    }

    @Test("finalize 清洗非法文件名字符")
    func finalizeSanitizes() async throws {
        let workdir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workdir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workdir) }

        let src = workdir.appendingPathComponent("src.mp4")
        try Data("x".utf8).write(to: src)
        let out = try await RecordingFileWriter.finalize(tempURL: src, to: workdir, filename: "a/b:c?")
        #expect(out.lastPathComponent == "a-b-c-.mp4")
    }
}
