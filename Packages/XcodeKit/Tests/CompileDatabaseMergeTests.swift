#if canImport(XCTest)
import XCTest
@testable import XcodeKit

final class CompileDatabaseMergeTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("compile-db-merge-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        super.tearDown()
    }

    private func writeEntries(_ entries: [[String: Any]], to url: URL) {
        let data = try! JSONSerialization.data(withJSONObject: entries, options: [])
        try! data.write(to: url)
    }

    private func readEntries(at url: URL) -> [[String: Any]] {
        let data = try! Data(contentsOf: url)
        return (try! JSONSerialization.jsonObject(with: data)) as! [[String: Any]]
    }

    private func entry(directory: String, file: String, module: String) -> [String: Any] {
        ["directory": directory, "file": file, "module_name": module, "command": "-module-name \(module)"]
    }

    // MARK: - First build (no existing database) promotes the new one as-is

    func testPromotesNewWhenNoExistingDatabase() {
        let newURL = tempDir.appendingPathComponent("new.json")
        let existingURL = tempDir.appendingPathComponent("existing.json") // does not exist
        let destURL = tempDir.appendingPathComponent(".compile")
        writeEntries([
            entry(directory: "/src", file: "A.swift", module: "App")
        ], to: newURL)

        let ok = XcodeSemanticIndexRunner.mergeCompileDatabase(new: newURL, existing: existingURL, into: destURL)

        XCTAssertTrue(ok)
        let result = readEntries(at: destURL)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["file"] as? String, "A.swift")
        // The new file should have been moved into place (consumed).
        XCTAssertFalse(FileManager.default.fileExists(atPath: newURL.path))
    }

    // MARK: - Incremental merge: rebuild of some files preserves others

    func testMergeOverwritesRebuiltFilesAndPreservesUntouchedOnes() {
        // Existing (full) database has two files.
        let existingURL = tempDir.appendingPathComponent("existing.json")
        writeEntries([
            entry(directory: "/src", file: "A.swift", module: "App"),       // will be rebuilt
            entry(directory: "/src", file: "B.swift", module: "App")        // will NOT be rebuilt
        ], to: existingURL)

        // Incremental parse only contains A.swift (the file that was recompiled), with a *changed*
        // module name to prove the overwrite actually happens.
        let newURL = tempDir.appendingPathComponent("new.json")
        writeEntries([
            entry(directory: "/src", file: "A.swift", module: "App_Updated")
        ], to: newURL)

        let destURL = tempDir.appendingPathComponent(".compile")
        let ok = XcodeSemanticIndexRunner.mergeCompileDatabase(new: newURL, existing: existingURL, into: destURL)

        XCTAssertTrue(ok)
        let result = readEntries(at: destURL)
        XCTAssertEqual(result.count, 2, "merge must keep B.swift and update A.swift")

        let byFile = Dictionary(uniqueKeysWithValues: result.map { ($0["file"] as! String, $0) })
        XCTAssertEqual(byFile["A.swift"]?["module_name"] as? String, "App_Updated", "rebuilt file takes new command")
        XCTAssertEqual(byFile["B.swift"]?["module_name"] as? String, "App", "untouched file preserved")
    }

    // MARK: - Scheme module survives even if its target wasn't rebuilt

    func testMergeRetainsSchemeModuleAcrossIncrementalParse() {
        // Existing DB includes the scheme module (App). The incremental parse only rebuilt a Lib file,
        // so the parsed result omits the scheme module — the merge must retain it from the existing DB.
        let existingURL = tempDir.appendingPathComponent("existing.json")
        writeEntries([
            entry(directory: "/src", file: "main.swift", module: "App"),
            entry(directory: "/src/Lib", file: "Util.swift", module: "Lib")
        ], to: existingURL)

        let newURL = tempDir.appendingPathComponent("new.json")
        writeEntries([
            entry(directory: "/src/Lib", file: "Util.swift", module: "Lib")
        ], to: newURL)

        let destURL = tempDir.appendingPathComponent(".compile")
        _ = XcodeSemanticIndexRunner.mergeCompileDatabase(new: newURL, existing: existingURL, into: destURL)

        let result = readEntries(at: destURL)
        let hasSchemeModule = result.contains { ($0["module_name"] as? String) == "App" }
        XCTAssertTrue(hasSchemeModule, "scheme module must survive an incremental parse that didn't rebuild it")
    }

    // MARK: - Invalid / empty new database is rejected (no clobber)

    func testEmptyNewDatabaseDoesNotClobberExisting() {
        let existingURL = tempDir.appendingPathComponent("existing.json")
        writeEntries([
            entry(directory: "/src", file: "A.swift", module: "App")
        ], to: existingURL)

        let newURL = tempDir.appendingPathComponent("new.json")
        writeEntries([], to: newURL) // empty parse (the known Xcode empty-extraction bug)

        let destURL = tempDir.appendingPathComponent(".compile")
        // Pre-existing dest so we can assert it is left untouched.
        writeEntries([entry(directory: "/src", file: "PREexisting.swift", module: "App")], to: destURL)

        let ok = XcodeSemanticIndexRunner.mergeCompileDatabase(new: newURL, existing: existingURL, into: destURL)

        XCTAssertFalse(ok, "empty new DB must not be merged")
        let result = readEntries(at: destURL)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0]["file"] as? String, "PREexisting.swift", "destination must be untouched")
    }
}
#endif
