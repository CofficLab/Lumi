import Foundation
import Testing
@testable import PluginAppStoreConnect

/// Chat Toolbar ASC 入口的「项目 → App 绑定」解析。
@Suite("ASC Chat Toolbar binding")
struct ASCChatToolbarBindingTests {

    // MARK: - Helpers

    /// 创建一个临时项目目录。
    private func makeProjectDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ASCChatToolbarTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 写入 `<project>/.lumi/app-store-connect/app.json`。
    private func writeAppConfiguration(projectPath: String, json: String) {
        let directory = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent(".lumi/app-store-connect", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("app.json")
        try? json.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    /// 写入一个最小 Xcode 工程（`project.pbxproj`）。
    private func writeXcodeProject(projectPath: String, bundleID: String) {
        let directory = URL(fileURLWithPath: projectPath, isDirectory: true)
            .appendingPathComponent("Demo.xcodeproj", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let contents = """
        // !$*UTF8*$!
        {
            objects = {
                A1 /* Debug */ = {
                    buildSettings = {
                        PRODUCT_BUNDLE_IDENTIFIER = "\(bundleID)";
                    };
                };
            };
        }
        """
        try? contents.write(
            to: directory.appendingPathComponent("project.pbxproj"),
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Tests

    @Test("app.json provides an explicit app id binding")
    func appConfigurationProvidesAppID() {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        writeAppConfiguration(
            projectPath: project.path,
            json: #"{"appID": "6758871065"}"#
        )

        let binding = ASCAppBindingLoader.load(projectPath: project.path)

        #expect(binding?.appID == "6758871065")
        #expect(binding?.bundleID == nil)
        #expect(binding?.isEmpty == false)
    }

    @Test("app.json provides an explicit bundle id binding")
    func appConfigurationProvidesBundleID() {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        writeAppConfiguration(
            projectPath: project.path,
            json: #"{"bundleID": "com.example.demo"}"#
        )

        let binding = ASCAppBindingLoader.load(projectPath: project.path)

        #expect(binding?.bundleID == "com.example.demo")
        #expect(binding?.appID == nil)
    }

    @Test("missing app.json yields no binding")
    func missingConfigurationYieldsNoBinding() {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        #expect(ASCAppBindingLoader.load(projectPath: project.path) == nil)
    }

    @Test("blank values are treated as absent")
    func blankValuesAreTreatedAsAbsent() {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        writeAppConfiguration(
            projectPath: project.path,
            json: #"{"appID": "  ", "bundleID": ""}"#
        )

        #expect(ASCAppBindingLoader.load(projectPath: project.path) == nil)
    }

    @Test("bundle id is detected from the Xcode project")
    func bundleIDIsDetectedFromXcodeProject() {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        writeXcodeProject(projectPath: project.path, bundleID: "com.example.detected")

        let detected = ASCBundleIDDetector.detectBundleID(projectPath: project.path)

        #expect(detected == "com.example.detected")
    }

    @Test("bundle id detection returns nil for a plain Swift package")
    func bundleIDDetectionReturnsNilForSwiftPackage() {
        let project = makeProjectDirectory()
        defer { try? FileManager.default.removeItem(at: project) }

        try? "let package = Package()".write(
            to: project.appendingPathComponent("Package.swift"),
            atomically: true,
            encoding: .utf8
        )

        #expect(ASCBundleIDDetector.detectBundleID(projectPath: project.path) == nil)
    }

    @Test("pbxproj parsing skips build-setting placeholders")
    func pbxprojParsingSkipsPlaceholders() {
        let contents = """
        buildSettings = {
            PRODUCT_BUNDLE_IDENTIFIER = "$(PRODUCT_NAME:rfc1034identifier)";
        };
        buildSettings = {
            PRODUCT_BUNDLE_IDENTIFIER = com.example.real;
        };
        """

        #expect(ASCBundleIDDetector.parseBundleID(fromPbxproj: contents) == "com.example.real")
    }

    @Test("pbxproj parsing returns nil when every value is a placeholder")
    func pbxprojParsingReturnsNilForPlaceholdersOnly() {
        let contents = """
        buildSettings = {
            PRODUCT_BUNDLE_IDENTIFIER = "$(PRODUCT_NAME:rfc1034identifier)";
        };
        """

        #expect(ASCBundleIDDetector.parseBundleID(fromPbxproj: contents) == nil)
    }
}
