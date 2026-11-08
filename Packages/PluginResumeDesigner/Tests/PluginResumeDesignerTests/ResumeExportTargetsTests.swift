import Foundation
import Testing
@testable import PluginResumeDesigner

@Suite("ResumeExportTargets")
struct ResumeExportTargetsTests {
    @Test("PDF 导出列出 PDF 与全部页 PNG，PNG 导出不含 PDF")
    func fileNamesMatchExportMode() {
        let both = ResumeExportTargets.fileNames(resumeID: "alice", pageCount: 3, pngOnly: false)
        #expect(both == ["alice.pdf", "alice-p01.png", "alice-p02.png", "alice-p03.png"])

        let pngOnly = ResumeExportTargets.fileNames(resumeID: "alice", pageCount: 2, pngOnly: true)
        #expect(pngOnly == ["alice-p01.png", "alice-p02.png"])
    }

    @Test("目标目录已有同名文件时全部报告，未冲突时不报告")
    func reportsEveryExistingTarget() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-export-targets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(ResumeExportTargets.existingFiles(
            resumeID: "alice", pageCount: 2, pngOnly: false, in: directory
        ).isEmpty)

        try Data().write(to: directory.appendingPathComponent("alice.pdf"))
        try Data().write(to: directory.appendingPathComponent("alice-p02.png"))

        let conflicts = ResumeExportTargets.existingFiles(
            resumeID: "alice", pageCount: 2, pngOnly: false, in: directory
        )
        #expect(conflicts.map(\.lastPathComponent) == ["alice.pdf", "alice-p02.png"])
    }

    @Test("PNG-only 导出不把已有 PDF 算作冲突")
    func pngOnlyIgnoresPDFConflict() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-export-targets-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data().write(to: directory.appendingPathComponent("alice.pdf"))

        #expect(ResumeExportTargets.existingFiles(
            resumeID: "alice", pageCount: 1, pngOnly: true, in: directory
        ).isEmpty)

        try Data().write(to: directory.appendingPathComponent("alice-p01.png"))
        let conflicts = ResumeExportTargets.existingFiles(
            resumeID: "alice", pageCount: 1, pngOnly: true, in: directory
        )
        #expect(conflicts.map(\.lastPathComponent) == ["alice-p01.png"])
    }
}
