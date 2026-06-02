import Testing
@testable import XcodeProjectGen

@Suite("XcodeProjectSpec Tests")
struct XcodeProjectSpecTests {

    @Test("创建空 Spec")
    func createEmptySpec() {
        let spec = XcodeProjectSpec(
            name: "TestProject",
            targets: []
        )
        #expect(spec.name == "TestProject")
        #expect(spec.targets.isEmpty)
        #expect(spec.schemes.isEmpty)
        #expect(spec.settings.isEmpty)
    }

    @Test("创建带 Target 的 Spec")
    func createSpecWithTarget() {
        let spec = XcodeProjectSpec(
            name: "MyApp",
            targets: [
                .app(
                    name: "MyApp",
                    platform: .iOS,
                    deploymentTarget: "17.0",
                    sources: ["Sources/MyApp"],
                    settings: [
                        .bundleIdentifier("com.example.MyApp"),
                        .developmentTeam("ABC123")
                    ]
                )
            ]
        )
        #expect(spec.targets.count == 1)
        #expect(spec.targets[0].name == "MyApp")
        #expect(spec.targets[0].kind == .app)
        #expect(spec.targets[0].platform == .iOS)
    }

    @Test("查询 App Targets")
    func queryAppTargets() {
        let spec = XcodeProjectSpec(
            name: "Test",
            targets: [
                .app(name: "App"),
                .framework(name: "Core"),
                .unitTest(name: "AppTests", targetDependency: "App"),
            ]
        )
        #expect(spec.appTargets.count == 1)
        #expect(spec.appTargets[0].name == "App")
        #expect(spec.frameworkTargets.count == 1)
        #expect(spec.frameworkTargets[0].name == "Core")
        #expect(spec.testTargets.count == 1)
        #expect(spec.testTargets[0].name == "AppTests")
    }

    @Test("收集远程依赖去重")
    func remoteDependencyDeduplication() {
        let spec = XcodeProjectSpec(
            name: "Test",
            targets: [
                .app(
                    name: "App",
                    dependencies: [
                        .remote(url: "https://github.com/Alamofire/Alamofire", product: "Alamofire", versionRequirement: .upToNextMajor("5.0.0")),
                        .remote(url: "https://github.com/Alamofire/Alamofire", product: "Alamofire", versionRequirement: .upToNextMajor("5.0.0")),
                    ]
                ),
                .framework(
                    name: "Core",
                    dependencies: [
                        .remote(url: "https://github.com/Alamofire/Alamofire", product: "Alamofire", versionRequirement: .upToNextMajor("5.0.0")),
                    ]
                ),
            ]
        )
        #expect(spec.remoteDependencies.count == 1)
    }

    @Test("按名称查找 Target")
    func findTargetByName() {
        let spec = XcodeProjectSpec(
            name: "Test",
            targets: [
                .app(name: "App"),
                .framework(name: "Core"),
            ]
        )
        #expect(spec.target(name: "App") != nil)
        #expect(spec.target(name: "Core") != nil)
        #expect(spec.target(name: "NotExist") == nil)
    }
}

@Suite("XcodeTargetSpec Tests")
struct XcodeTargetSpecTests {

    @Test("便捷工厂方法 - App")
    func appFactoryMethod() {
        let target = XcodeTargetSpec.app(
            name: "MyApp",
            platform: .iOS,
            deploymentTarget: "18.0",
            sources: ["Sources/MyApp"],
            settings: [.bundleIdentifier("com.test.MyApp")]
        )
        #expect(target.kind == .app)
        #expect(target.platform == .iOS)
        #expect(target.deploymentTarget == "18.0")
        #expect(target.sources == ["Sources/MyApp"])
    }

    @Test("便捷工厂方法 - Framework")
    func frameworkFactoryMethod() {
        let target = XcodeTargetSpec.framework(
            name: "MyFramework",
            sources: ["Sources/MyFramework"]
        )
        #expect(target.kind == .framework)
    }

    @Test("便捷工厂方法 - Unit Test")
    func unitTestFactoryMethod() {
        let target = XcodeTargetSpec.unitTest(
            name: "MyTests",
            targetDependency: "MyApp"
        )
        #expect(target.kind == .unitTestBundle)
        #expect(target.dependencies.contains(where: {
            if case .target(let name) = $0 { return name == "MyApp" }
            return false
        }))
    }

    @Test("便捷工厂方法 - App Extension")
    func appExtensionFactoryMethod() {
        let target = XcodeTargetSpec.appExtension(
            name: "MyExtension",
            entitlementsPath: "MyExtension/MyExtension.entitlements"
        )
        #expect(target.kind == .appExtension)
        #expect(target.entitlementsPath == "MyExtension/MyExtension.entitlements")
    }
}

@Suite("XcodeDependencySpec Tests")
struct XcodeDependencySpecTests {

    @Test("远程依赖")
    func remoteDependency() {
        let dep = XcodeDependencySpec.remote(
            url: "https://github.com/Alamofire/Alamofire",
            product: "Alamofire",
            versionRequirement: .upToNextMajor("5.0.0")
        )
        if case .remote(let url, let product, let req) = dep {
            #expect(url == "https://github.com/Alamofire/Alamofire")
            #expect(product == "Alamofire")
            if case .upToNextMajor(let v) = req {
                #expect(v == "5.0.0")
            } else {
                Issue.record("Expected upToNextMajor")
            }
        } else {
            Issue.record("Expected remote dependency")
        }
    }

    @Test("本地依赖")
    func localDependency() {
        let dep = XcodeDependencySpec.local(path: "Packages/MyCore", product: "MyCore")
        if case .local(let path, let product) = dep {
            #expect(path == "Packages/MyCore")
            #expect(product == "MyCore")
        } else {
            Issue.record("Expected local dependency")
        }
    }

    @Test("Target 依赖")
    func targetDependency() {
        let dep = XcodeDependencySpec.target(name: "Core")
        if case .target(let name) = dep {
            #expect(name == "Core")
        } else {
            Issue.record("Expected target dependency")
        }
    }

    @Test("Framework 依赖")
    func frameworkDependency() {
        let dep = XcodeDependencySpec.framework(name: "UIKit")
        if case .framework(let name) = dep {
            #expect(name == "UIKit")
        } else {
            Issue.record("Expected framework dependency")
        }
    }

    @Test("版本要求类型")
    func versionRequirementTypes() {
        let cases: [(XcodeVersionRequirement, String)] = [
            (.upToNextMajor("1.0.0"), "upToNextMajor"),
            (.upToNextMinor("1.0.0"), "upToNextMinor"),
            (.exact("1.0.0"), "exact"),
            (.branch("main"), "branch"),
            (.revision("abc123"), "revision"),
        ]
        for (req, _) in cases {
            // 确保所有枚举值都能正确创建
            switch req {
            case .upToNextMajor, .upToNextMinor, .exact, .branch, .revision:
                break // OK
            }
        }
    }
}

@Suite("XcodeBuildSetting Tests")
struct XcodeBuildSettingTests {

    @Test("常用 Build Settings")
    func commonBuildSettings() {
        let settings: [(XcodeBuildSetting, String, String)] = [
            (.bundleIdentifier("com.test.app"), "PRODUCT_BUNDLE_IDENTIFIER", "com.test.app"),
            (.developmentTeam("ABC123"), "DEVELOPMENT_TEAM", "ABC123"),
            (.infoPlistPath("Info.plist"), "INFOPLIST_FILE", "Info.plist"),
        ]
        for (setting, expectedKey, expectedValue) in settings {
            let (key, value) = setting.keyValue
            #expect(key == expectedKey)
            #expect(value == expectedValue)
        }
    }

    @Test("自定义 Build Setting")
    func customBuildSetting() {
        let setting = XcodeBuildSetting.custom(key: "MY_SETTING", value: "my_value")
        let (key, value) = setting.keyValue
        #expect(key == "MY_SETTING")
        #expect(value == "my_value")
    }
}

@Suite("XcodePlatform Tests")
struct XcodePlatformTests {

    @Test("平台属性")
    func platformProperties() {
        #expect(XcodePlatform.iOS.sdkRoot == "iphoneos")
        #expect(XcodePlatform.iOS.deploymentTargetKey == "IPHONEOS_DEPLOYMENT_TARGET")
        #expect(XcodePlatform.iOS.targetedDeviceFamily == "1,2")

        #expect(XcodePlatform.macOS.sdkRoot == "macosx")
        #expect(XcodePlatform.macOS.deploymentTargetKey == "MACOSX_DEPLOYMENT_TARGET")
        #expect(XcodePlatform.macOS.targetedDeviceFamily == nil)

        #expect(XcodePlatform.watchOS.sdkRoot == "watchos")
        #expect(XcodePlatform.tvOS.sdkRoot == "appletvos")
        #expect(XcodePlatform.visionOS.sdkRoot == "xros")
    }
}
