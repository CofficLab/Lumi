@testable import EditorSwiftPlugin
import Testing
import XcodeProjectGen

@Test func parseTargetBuildsAppTargetSpec() throws {
    let spec = try GenerateXcodeProjectToolParser.parseTarget([
        "name": "MyApp",
        "kind": "app",
        "platform": "macOS",
        "deployment_target": "14.0",
        "sources": ["Sources/App.swift"],
        "settings": [
            ["key": "PRODUCT_BUNDLE_IDENTIFIER", "value": "com.example.app"],
        ],
    ])

    #expect(spec.name == "MyApp")
    #expect(spec.kind == .app)
    #expect(spec.platform == .macOS)
    #expect(spec.deploymentTarget == "14.0")
    #expect(spec.sources == ["Sources/App.swift"])
    #expect(spec.settings.count == 1)
}

@Test func parseTargetKindRejectsUnknownKind() {
    #expect(throws: GenerateXcodeProjectToolError.self) {
        try GenerateXcodeProjectToolParser.parseTargetKind("library")
    }
}

@Test func parseDependencySupportsTargetLocalRemoteAndFramework() throws {
    if case .target(let name) = try GenerateXcodeProjectToolParser.parseDependency(["target": "Core"]) {
        #expect(name == "Core")
    } else {
        Issue.record("Expected target dependency")
    }

    if case .local(let path, let product) = try GenerateXcodeProjectToolParser.parseDependency([
        "local_path": "../Packages/Foo",
        "product": "Foo",
    ]) {
        #expect(path == "../Packages/Foo")
        #expect(product == "Foo")
    } else {
        Issue.record("Expected local dependency")
    }

    if case .remote(let url, let product, let versionRequirement) = try GenerateXcodeProjectToolParser.parseDependency([
        "remote_url": "https://github.com/example/Foo.git",
        "product": "Foo",
        "version_kind": "exact",
        "version": "2.0.0",
    ]) {
        #expect(url == "https://github.com/example/Foo.git")
        #expect(product == "Foo")
        if case .exact(let version) = versionRequirement {
            #expect(version == "2.0.0")
        } else {
            Issue.record("Expected exact version requirement")
        }
    } else {
        Issue.record("Expected remote dependency")
    }

    if case .framework(let name) = try GenerateXcodeProjectToolParser.parseDependency(["framework": "UIKit"]) {
        #expect(name == "UIKit")
    } else {
        Issue.record("Expected framework dependency")
    }
}

@Test func parseDependencyThrowsForInvalidSpec() {
    #expect(throws: GenerateXcodeProjectToolError.self) {
        try GenerateXcodeProjectToolParser.parseDependency(["unknown": "value"])
    }
}

@Test func parseSchemeRequiresNameAndBuildTargets() throws {
    let scheme = try GenerateXcodeProjectToolParser.parseScheme([
        "name": "MyApp",
        "build_targets": ["MyApp", "MyAppTests"],
    ])
    #expect(scheme.name == "MyApp")
    #expect(scheme.buildTargets == ["MyApp", "MyAppTests"])
}

@Test func parseBuildSettingMapsKnownKeys() {
    if case .developmentTeam(let team) = GenerateXcodeProjectToolParser.parseBuildSetting(key: "DEVELOPMENT_TEAM", value: "TEAM") {
        #expect(team == "TEAM")
    } else {
        Issue.record("Expected development team setting")
    }

    if case .custom(let key, let value) = GenerateXcodeProjectToolParser.parseBuildSetting(key: "CUSTOM_FLAG", value: "YES") {
        #expect(key == "CUSTOM_FLAG")
        #expect(value == "YES")
    } else {
        Issue.record("Expected custom setting")
    }
}
