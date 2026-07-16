import Testing
import Foundation
@testable import FileSystemKit

@Suite("FileTreeService Tests")
struct FileTreeServiceTests {

    // MARK: - Helper

    /// 创建临时测试目录，自动在 deinit 中清理
    private func makeTempDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// 在目录中创建指定名称的空文件
    private func createFile(in dir: URL, name: String) throws -> URL {
        let fileURL = dir.appendingPathComponent(name)
        let data = "test content".data(using: .utf8)!
        try data.write(to: fileURL)
        return fileURL
    }

    /// 在目录中创建子目录
    private func createSubfolder(in dir: URL, name: String) throws -> URL {
        let subURL = dir.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: subURL, withIntermediateDirectories: true)
        return subURL
    }

    // MARK: - isDirectory

    @Test("isDirectory returns true for directory")
    func isDirectoryReturnsTrueForDirectory() throws {
        let dir = try makeTempDirectory()
        #expect(FileTreeService.isDirectory(dir) == true)
    }

    @Test("isDirectory returns false for file")
    func isDirectoryReturnsFalseForFile() throws {
        let dir = try makeTempDirectory()
        let file = try createFile(in: dir, name: "test.txt")
        #expect(FileTreeService.isDirectory(file) == false)
    }

    @Test("isDirectory returns false for nonexistent path")
    func isDirectoryReturnsFalseForNonexistent() {
        let fakeURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString)")
        #expect(FileTreeService.isDirectory(fakeURL) == false)
    }

    // MARK: - filterAndSortContents

    @Test("filterAndSortContents filters .DS_Store and .git by default")
    func filterFiltersHiddenFiles() throws {
        let dir = try makeTempDirectory()
        let dsStore = try createFile(in: dir, name: ".DS_Store")
        let gitDir = try createSubfolder(in: dir, name: ".git")
        let swiftFile = try createFile(in: dir, name: "main.swift")

        let result = FileTreeService.filterAndSortContents([dsStore, gitDir, swiftFile])
        let names = result.map(\.lastPathComponent)
        #expect(names == ["main.swift"])
    }

    @Test("filterAndSortContents places folders before files")
    func sortFoldersFirst() throws {
        let dir = try makeTempDirectory()
        let file1 = try createFile(in: dir, name: "alpha.txt")
        let folder1 = try createSubfolder(in: dir, name: "bravo")
        let file2 = try createFile(in: dir, name: "charlie.md")
        let folder2 = try createSubfolder(in: dir, name: "delta")

        let result = FileTreeService.filterAndSortContents([file1, folder1, file2, folder2])
        let names = result.map(\.lastPathComponent)

        // 文件夹在前，然后各自按名称排序
        // folders: bravo, delta; files: alpha.txt, charlie.md
        #expect(names == ["bravo", "delta", "alpha.txt", "charlie.md"])
    }

    @Test("filterAndSortContents sorts names with localized standard compare")
    func sortLocalizedStandard() throws {
        let dir = try makeTempDirectory()
        let a = try createFile(in: dir, name: "b.txt")
        let b = try createFile(in: dir, name: "a.txt")
        let c = try createFile(in: dir, name: "c.txt")

        let result = FileTreeService.filterAndSortContents([a, b, c])
        let names = result.map(\.lastPathComponent)
        #expect(names == ["a.txt", "b.txt", "c.txt"])
    }

    @Test("filterAndSortContents uses custom hidden names")
    func filterCustomHiddenNames() throws {
        let dir = try makeTempDirectory()
        let file1 = try createFile(in: dir, name: "ignore.me")
        let file2 = try createFile(in: dir, name: "keep.me")

        let result = FileTreeService.filterAndSortContents(
            [file1, file2],
            hiddenNames: ["ignore.me"]
        )
        let names = result.map(\.lastPathComponent)
        #expect(names == ["keep.me"])
    }

    @Test("filterAndSortContents returns empty for empty input")
    func filterEmptyInput() {
        let result = FileTreeService.filterAndSortContents([])
        #expect(result.isEmpty)
    }

    // MARK: - loadContents

    @Test("loadContents returns sorted directory listing")
    func loadContentsReturnsSorted() throws {
        let dir = try makeTempDirectory()
        _ = try createFile(in: dir, name: "z.txt")
        _ = try createSubfolder(in: dir, name: "a_folder")
        _ = try createFile(in: dir, name: ".DS_Store")
        _ = try createFile(in: dir, name: "m.txt")

        let result = try FileTreeService.loadContents(of: dir)
        let names = result.map(\.lastPathComponent)

        // .DS_Store 过滤掉；文件夹在前
        #expect(names == ["a_folder", "m.txt", "z.txt"])
    }

    @Test("loadContents throws for nonexistent directory")
    func loadContentsThrowsForNonexistent() {
        let fakeURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
        #expect(throws: CocoaError.self) {
            try FileTreeService.loadContents(of: fakeURL)
        }
    }

    @Test("loadContents returns empty for empty directory")
    func loadContentsReturnsEmpty() throws {
        let dir = try makeTempDirectory()
        let result = try FileTreeService.loadContents(of: dir)
        #expect(result.isEmpty)
    }

    // MARK: - iconSFSymbol

    @Test("iconSFSymbol returns correct icons for known extensions")
    func iconSFSymbolKnownExtensions() {
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "swift") == "swift")
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "json") == "brace")
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "md") == "doc.richtext")
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "sh") == "terminal")
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "py") == "doc.text.below.ecg")
    }

    @Test("iconSFSymbol is case insensitive")
    func iconSFSymbolCaseInsensitive() {
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "SWIFT") == "swift")
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "Json") == "brace")
    }

    @Test("iconSFSymbol returns doc for unknown extensions")
    func iconSFSymbolUnknownExtension() {
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "xyz123") == "doc")
        #expect(FileTreeService.iconSFSymbol(forFileExtension: "") == "doc")
    }

    @Test("iconSFSymbol for URL returns folder.fill for directory")
    func iconSFSymbolForURLDirectory() throws {
        let dir = try makeTempDirectory()
        #expect(FileTreeService.iconSFSymbol(for: dir) == "folder.fill")
    }

    @Test("iconSFSymbol for URL returns extension-based icon for file")
    func iconSFSymbolForURLFile() throws {
        let dir = try makeTempDirectory()
        let file = try createFile(in: dir, name: "code.swift")
        #expect(FileTreeService.iconSFSymbol(for: file) == "swift")
    }

    // MARK: - displayName

    @Test("displayName returns last path component")
    func displayNameReturnsLastPathComponent() {
        let url = URL(fileURLWithPath: "/Users/test/project/main.swift")
        #expect(FileTreeService.displayName(for: url) == "main.swift")
    }

    // MARK: - modificationDate

    @Test("modificationDate returns date for existing file")
    func modificationDateReturnsDate() throws {
        let dir = try makeTempDirectory()
        let file = try createFile(in: dir, name: "test.txt")
        let date = FileTreeService.modificationDate(for: file)
        #expect(date != nil)
    }

    @Test("modificationDate returns nil for nonexistent file")
    func modificationDateReturnsNilForNonexistent() {
        let fakeURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).txt")
        let date = FileTreeService.modificationDate(for: fakeURL)
        #expect(date == nil)
    }

    // MARK: - formatDate

    @Test("formatDate returns non-empty string for valid date")
    func formatDateReturnsNonEmpty() {
        let now = Date()
        let result = FileTreeService.formatDate(now)
        #expect(!result.isEmpty)
    }

    @Test("formatDate returns empty string for nil")
    func formatDateReturnsEmptyForNil() {
        let result = FileTreeService.formatDate(nil)
        #expect(result.isEmpty)
    }

    // MARK: - createFile

    @Test("createFile creates file and returns URL")
    func createFileSuccess() throws {
        let dir = try makeTempDirectory()
        let result = FileTreeService.createFile(in: dir, name: "newfile.txt")
        #expect(result != nil)
        #expect(FileManager.default.fileExists(atPath: result!.path))
    }

    @Test("createFile returns nil for empty name")
    func createFileEmptyName() throws {
        let dir = try makeTempDirectory()
        let result = FileTreeService.createFile(in: dir, name: "")
        #expect(result == nil)
    }

    @Test("createFile rejects path-like names")
    func createFilePathLikeName() throws {
        let dir = try makeTempDirectory()
        let result = FileTreeService.createFile(in: dir, name: "../outside.txt")
        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: dir.deletingLastPathComponent().appendingPathComponent("outside.txt").path))
    }

    @Test("createFile returns nil if file already exists")
    func createFileAlreadyExists() throws {
        let dir = try makeTempDirectory()
        _ = try createFile(in: dir, name: "exists.txt")
        let result = FileTreeService.createFile(in: dir, name: "exists.txt")
        #expect(result == nil)
    }

    // MARK: - createFolder

    @Test("createFolder creates directory and returns URL")
    func createFolderSuccess() throws {
        let dir = try makeTempDirectory()
        let result = FileTreeService.createFolder(in: dir, name: "newfolder")
        #expect(result != nil)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: result!.path, isDirectory: &isDir))
        #expect(isDir.boolValue)
    }

    @Test("createFolder returns nil for empty name")
    func createFolderEmptyName() throws {
        let dir = try makeTempDirectory()
        let result = FileTreeService.createFolder(in: dir, name: "")
        #expect(result == nil)
    }

    @Test("createFolder rejects current and parent directory names")
    func createFolderPathTraversalNames() throws {
        let dir = try makeTempDirectory()
        #expect(FileTreeService.createFolder(in: dir, name: ".") == nil)
        #expect(FileTreeService.createFolder(in: dir, name: "..") == nil)
    }

    @Test("createFolder returns nil if folder already exists")
    func createFolderAlreadyExists() throws {
        let dir = try makeTempDirectory()
        _ = try createSubfolder(in: dir, name: "exists")
        let result = FileTreeService.createFolder(in: dir, name: "exists")
        #expect(result == nil)
    }

    // MARK: - renameItem

    @Test("renameItem renames file and returns new URL")
    func renameItemSuccess() throws {
        let dir = try makeTempDirectory()
        let original = try createFile(in: dir, name: "old.txt")
        let result = FileTreeService.renameItem(at: original, newName: "new.txt")

        #expect(result != nil)
        #expect(result!.lastPathComponent == "new.txt")
        #expect(FileManager.default.fileExists(atPath: result!.path))
        #expect(!FileManager.default.fileExists(atPath: original.path))
    }

    @Test("renameItem returns nil for empty name")
    func renameItemEmptyName() throws {
        let dir = try makeTempDirectory()
        let file = try createFile(in: dir, name: "test.txt")
        let result = FileTreeService.renameItem(at: file, newName: "")
        #expect(result == nil)
    }

    @Test("renameItem rejects path-like names")
    func renameItemPathLikeName() throws {
        let dir = try makeTempDirectory()
        let file = try createFile(in: dir, name: "test.txt")
        let result = FileTreeService.renameItem(at: file, newName: "../escaped.txt")
        #expect(result == nil)
        #expect(FileManager.default.fileExists(atPath: file.path))
        #expect(!FileManager.default.fileExists(atPath: dir.deletingLastPathComponent().appendingPathComponent("escaped.txt").path))
    }

    @Test("renameItem returns nil if target already exists")
    func renameItemTargetExists() throws {
        let dir = try makeTempDirectory()
        let file1 = try createFile(in: dir, name: "file1.txt")
        _ = try createFile(in: dir, name: "file2.txt")
        let result = FileTreeService.renameItem(at: file1, newName: "file2.txt")
        #expect(result == nil)
    }

    // MARK: - trashItem

    @Test("trashItem moves file to trash")
    func trashItemSuccess() throws {
        let dir = try makeTempDirectory()
        let file = try createFile(in: dir, name: "trashme.txt")
        let result = FileTreeService.trashItem(at: file)
        #expect(result == true)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("trashItem returns false for nonexistent file")
    func trashItemNonexistent() {
        let fakeURL = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString).txt")
        let result = FileTreeService.trashItem(at: fakeURL)
        #expect(result == false)
    }
}
