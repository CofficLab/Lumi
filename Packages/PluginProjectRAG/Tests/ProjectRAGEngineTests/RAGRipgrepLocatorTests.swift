import Foundation
import Testing
@testable import ProjectRAGEngine

/// ripgrep 必须随应用开箱可用，不依赖用户机器是否安装 rg。
@Suite struct RAGRipgrepLocatorTests {

    @Test func bundledRipgrepResolvesAndRuns() throws {
        let executable = try #require(RAGRipgrepLocator.executable())
        let bundled = try #require(Bundle.module.url(forResource: "rg", withExtension: nil))
        #expect(executable.path == bundled.path)

        let process = Process()
        process.executableURL = executable
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(output.contains("ripgrep"))
    }

    @Test func bundledCandidatePrecedesSystemPaths() throws {
        let bundled = try #require(Bundle.module.url(forResource: "rg", withExtension: nil))
        let candidates = RAGRipgrepLocator.candidates()
        let bundledIndex = try #require(candidates.firstIndex { $0.path == bundled.path })
        let pathEntries = ProcessInfo.processInfo.environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        for entry in pathEntries {
            let systemPath = "\(entry)/rg"
            if let systemIndex = candidates.firstIndex(where: { $0.path == systemPath }) {
                #expect(bundledIndex < systemIndex)
            }
        }
    }

    @Test func bundledRipgrepIsUniversal() throws {
        let bundled = try #require(Bundle.module.url(forResource: "rg", withExtension: nil))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lipo")
        process.arguments = ["-archs", bundled.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let archs = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(archs.contains("arm64"))
        #expect(archs.contains("x86_64"))
    }
}