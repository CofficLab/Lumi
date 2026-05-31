import Foundation
import Testing
@testable import PluginVueEditor

@Test func packageLoads() async throws {
    #expect(true)
}

@Test func cssModulesParserHandlesMultiLineRules() {
    let css = """
    .container, .wrapper {
        display: flex;
        color: red;
    }
    """

    let entries = CSSModulesTypeGenerator.parseClassNames(from: css)

    #expect(entries.map(\.name) == ["container", "wrapper"])
    #expect(entries.first?.properties == ["display: flex", "color: red"])
}

@Test func cssModulesParserHandlesSingleLineRules() {
    let css = ".button { color: blue; font-weight: 600; }"

    let entries = CSSModulesTypeGenerator.parseClassNames(from: css)

    #expect(entries.count == 1)
    #expect(entries.first?.name == "button")
    #expect(entries.first?.properties == ["color: blue", "font-weight: 600"])
}

@Test func vueScannerRelativePathOnlyDropsProjectRootPrefix() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let nestedDirectory = projectURL
        .appendingPathComponent("src/components/tmp")
        .appendingPathComponent(projectURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
    let componentURL = nestedDirectory.appendingPathComponent("user-card.vue")
    try "<template />".write(to: componentURL, atomically: true, encoding: .utf8)

    let entries = VueProjectScanner.scan(projectPath: projectURL.path)

    #expect(entries.first?.name == "UserCard")
    #expect(entries.first?.relativePath == "src/components/tmp/\(projectURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/user-card.vue")
}

@Test func vueScannerRelativePathRejectsSiblingWithSharedPrefix() {
    let fileURL = URL(fileURLWithPath: "/tmp/vue-app-copy/src/App.vue")

    #expect(VueProjectScanner.relativePath(for: fileURL, rootPath: "/tmp/vue-app") == "App.vue")
}

@Test func vueScannerImportPathIsRelativeToCurrentFile() {
    let component = VueProjectScanner.ComponentEntry(
        name: "UserCard",
        path: "/tmp/vue-app/src/components/UserCard.vue",
        relativePath: "src/components/UserCard.vue"
    )
    let currentFile = URL(fileURLWithPath: "/tmp/vue-app/src/views/Home.vue")

    #expect(VueProjectScanner.importPath(for: component, relativeTo: currentFile) == "../components/UserCard")
}

@Test func vueScannerImportPathUsesDotSlashForSiblingComponent() {
    let component = VueProjectScanner.ComponentEntry(
        name: "UserCard",
        path: "/tmp/vue-app/src/views/UserCard.vue",
        relativePath: "src/views/UserCard.vue"
    )
    let currentFile = URL(fileURLWithPath: "/tmp/vue-app/src/views/Home.vue")

    #expect(VueProjectScanner.importPath(for: component, relativeTo: currentFile) == "./UserCard")
}

@Test func vueComponentInfoDetectsScopedSlotProps() {
    let content = """
    <template>
        <slot :item="item" v-bind:state="state" />
    </template>
    """

    let info = VueComponentInfo.parse(
        from: content,
        filePath: "/tmp/vue-app/src/components/UserCard.vue",
        vueVersion: .vue3
    )

    #expect(info.slots.first?.name == "default")
    #expect(info.slots.first?.props == ["(scoped)"])
}

@Test func vueComponentInfoParsesObjectEmitNames() {
    let content = """
    <script setup>
    const emit = defineEmits({
        submit: null,
        'save-item': null,
        "update:modelValue": null
    })
    </script>
    """

    let info = VueComponentInfo.parse(
        from: content,
        filePath: "/tmp/vue-app/src/components/UserCard.vue",
        vueVersion: .vue3
    )

    #expect(info.emits.map(\.name) == ["submit", "save-item", "update:modelValue"])
}

@Test func vueCompilerOptionsIgnoreEmptyTSConfigJSX() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }
    try writeTSConfig(jsx: "", to: projectURL)

    let options = VueCompilerOptions.read(from: projectURL.path)

    #expect(options.jsxEnabled == false)
}

@Test func vueCompilerOptionsEnableTSConfigJSXWhenExplicit() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }
    try writeTSConfig(jsx: "react-jsx", to: projectURL)

    let options = VueCompilerOptions.read(from: projectURL.path)

    #expect(options.jsxEnabled == true)
}

@Test func viteBridgeDetectsUTF16VueConfig() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try """
    import vue from '@vitejs/plugin-vue'

    export default {
      plugins: [vue()],
      server: {
        host: '0.0.0.0',
        port: 4321
      }
    }
    """.write(to: projectURL.appendingPathComponent("vite.config.ts"), atomically: true, encoding: .utf16)

    let config = ViteBridge.detect(projectPath: projectURL.path)

    #expect(config?.isVueProject == true)
    #expect(config?.devPort == 4321)
    #expect(config?.devHost == "0.0.0.0")
}

@Test func vueCompilerOptionsReadsUTF16ViteJSXConfig() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try """
    import vue from '@vitejs/plugin-vue'
    import vueJsx from '@vitejs/plugin-vue-jsx'

    export default {
      plugins: [vue(), vueJsx()]
    }
    """.write(to: projectURL.appendingPathComponent("vite.config.ts"), atomically: true, encoding: .utf16)

    let options = VueCompilerOptions.read(from: projectURL.path)

    #expect(options.jsxEnabled == true)
    #expect(options.sourceDescription.contains("vite.config"))
}

@Test func autoImportRegistryReadsUTF16DeclarationFiles() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    try """
    declare module '@vue/runtime-core' {
      export interface GlobalComponents {
        UserCard: typeof import('./src/components/UserCard.vue')['default']
      }
    }
    """.write(
        to: projectURL.appendingPathComponent("components.d.ts"),
        atomically: true,
        encoding: .utf16
    )
    try """
    export {}
    declare global {
      const useUserStore: typeof import('./src/stores/user')['useUserStore']
    }
    """.write(
        to: projectURL.appendingPathComponent("auto-imports.d.ts"),
        atomically: true,
        encoding: .utf16
    )

    let registry = AutoImportRegistry.scan(projectPath: projectURL.path)

    #expect(registry.components["UserCard"]?.importFrom == "./src/components/UserCard.vue")
    #expect(registry.apis["useUserStore"]?.importFrom == "./src/stores/user")
}

@Test func componentRenamerUpdatesUTF16ReferenceFilesAndPreservesEncoding() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let oldURL = projectURL.appendingPathComponent("src/components/UserCard.vue")
    try FileManager.default.createDirectory(at: oldURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try "<template><section /></template>\n".write(to: oldURL, atomically: true, encoding: .utf8)

    let viewURL = projectURL.appendingPathComponent("src/views/Home.vue")
    try FileManager.default.createDirectory(at: viewURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    <script setup>
    import UserCard from '../components/UserCard.vue'
    </script>
    <template>
      <UserCard />
      <user-card />
    </template>
    """.write(to: viewURL, atomically: true, encoding: .utf16)

    let plan = ComponentRenamer.plan(
        oldPath: oldURL.path,
        newName: "AccountCard",
        projectPath: projectURL.path
    )
    #expect(plan.affectedFiles.contains { URL(fileURLWithPath: $0.path).lastPathComponent == "Home.vue" })

    let result = ComponentRenamer.rename(plan: plan)

    #expect(result.success)
    #expect(FileManager.default.fileExists(atPath: plan.newPath))

    var encoding = String.Encoding.utf8
    let updated = try String(contentsOf: viewURL, usedEncoding: &encoding)
    #expect(encoding == .utf16)
    #expect(updated.contains("import AccountCard from '../components/AccountCard.vue'"))
    #expect(updated.contains("<AccountCard />"))
    #expect(updated.contains("<account-card />"))
}

@Test func propDrillingAssistantReadsUTF16ParentComponents() throws {
    let projectURL = try makeTemporaryVueProject()
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let childURL = projectURL.appendingPathComponent("src/components/UserCard.vue")
    try FileManager.default.createDirectory(at: childURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let childContent = """
    <script setup lang="ts">
    defineProps<{ title: string }>()
    </script>
    <template><section>{{ title }}</section></template>
    """
    try childContent.write(to: childURL, atomically: true, encoding: .utf8)

    let parentURL = projectURL.appendingPathComponent("src/views/Home.vue")
    try FileManager.default.createDirectory(at: parentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try """
    <template>
      <UserCard :title="pageTitle" />
    </template>
    """.write(to: parentURL, atomically: true, encoding: .utf16)

    let info = VueComponentInfo.parse(from: childContent, filePath: childURL.path, vueVersion: .vue3)
    #expect(info.props.contains { $0.name == "title" })

    let analysis = PropDrillingAssistant.analyze(
        propName: "title",
        componentInfo: info,
        projectPath: projectURL.path
    )

    let resolvedParentPath = parentURL.resolvingSymlinksInPath().path
    #expect(analysis?.path.contains {
        URL(fileURLWithPath: $0.filePath).resolvingSymlinksInPath().path == resolvedParentPath
            && $0.passType == .templateBinding
    } == true)
}

private func makeTemporaryVueProject() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginVueEditorTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func writeTSConfig(jsx: String, to projectURL: URL) throws {
    let json = """
    {
      "compilerOptions": {
        "jsx": "\(jsx)"
      }
    }
    """
    try json.write(to: projectURL.appendingPathComponent("tsconfig.json"), atomically: true, encoding: .utf8)
}
