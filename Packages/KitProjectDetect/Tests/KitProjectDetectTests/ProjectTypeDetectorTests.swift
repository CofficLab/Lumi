import Foundation
import Testing

@testable import KitProjectDetect

@Suite("ProjectTypeDetector")
struct ProjectTypeDetectorTests {
    @Test("a Swift package root is detected as Swift")
    func detectsSwiftPackage() {
        let descriptor = ProjectTypeDetector.detect(rootEntryNames: ["Package.swift", "README.md"])
        #expect(descriptor.labels == ["Swift (Xcode / SPM)"])
        #expect(descriptor.symbolName == "swift")
        #expect(!descriptor.isUnknown)
    }

    @Test("an Xcode project is detected as Swift by suffix")
    func detectsXcodeProjectBySuffix() {
        let descriptor = ProjectTypeDetector.detect(rootEntryNames: ["Lumi.xcodeproj", "LumiApp"])
        #expect(descriptor.labels == ["Swift (Xcode / SPM)"])
    }

    @Test("a Node root is detected as Node")
    func detectsNode() {
        let descriptor = ProjectTypeDetector.detect(rootEntryNames: ["package.json"])
        #expect(descriptor.labels == ["Node / JavaScript"])
    }

    @Test("a polyglot root reports every matched type in rule order")
    func detectsMultipleTypesInRuleOrder() {
        let descriptor = ProjectTypeDetector.detect(rootEntryNames: ["package.json", "Cargo.toml", "Package.swift"])
        #expect(descriptor.labels == ["Swift (Xcode / SPM)", "Node / JavaScript", "Rust"])
        #expect(descriptor.symbolName == "swift")
    }

    @Test("an unrecognized root is unknown rather than empty text")
    func unknownRoot() {
        let descriptor = ProjectTypeDetector.detect(rootEntryNames: ["notes", "todo.txt"])
        #expect(descriptor.isUnknown)
        #expect(descriptor.labels.isEmpty)
        #expect(descriptor.displayText == nil)
        #expect(descriptor.symbolName == "folder")
    }

    @Test("a directory that cannot be read degrades to unknown")
    func unreadableDirectory() {
        let descriptor = ProjectTypeDetector.detect(at: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"))
        #expect(descriptor.isUnknown)
    }

    @Test("the display text joins multiple types with a semicolon")
    func displayTextJoinsTypes() {
        let descriptor = ProjectTypeDetector.detect(rootEntryNames: ["package.json", "go.mod"])
        #expect(descriptor.displayText == "Node / JavaScript; Go")
    }

    @Test("the set based overload matches the array based one")
    func setOverloadMatchesArrayOverload() {
        let names: Set<String> = ["Cargo.toml", "go.mod"]
        #expect(
            ProjectTypeDetector.detect(rootEntryNames: names)
                == ProjectTypeDetector.detect(rootEntryNames: Array(names))
        )
    }
}
