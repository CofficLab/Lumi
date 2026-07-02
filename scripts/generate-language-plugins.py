#!/usr/bin/env python3
"""Generate minimal highlight language plugins from EditorLanguages resources."""

from __future__ import annotations

import os
import shutil
import textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGINS = os.path.join(ROOT, "Plugins")
# Resources were migrated from Packages/EditorLanguages/Sources/Resources into each plugin.
RESOURCES_SRC = os.path.join(ROOT, "Packages/EditorLanguages/Sources/Resources")

# grammar_id -> (plugin_name, language_id, display_name, extensions, spm_url, spm_product, tree_sitter_fn)
LANGUAGES = {
    "python": ("EditorPythonPlugin", "python", "Python", ["py", "pyw"], "https://github.com/tree-sitter/tree-sitter-python.git", "TreeSitterPython", "tree_sitter_python", "master"),
    "rust": ("EditorRustPlugin", "rust", "Rust", ["rs"], "https://github.com/tree-sitter/tree-sitter-rust.git", "TreeSitterRust", "tree_sitter_rust", "master"),
    "ruby": ("EditorRubyPlugin", "ruby", "Ruby", ["rb", "rake"], "https://github.com/tree-sitter/tree-sitter-ruby.git", "TreeSitterRuby", "tree_sitter_ruby", "master"),
    "kotlin": ("EditorKotlinPlugin", "kotlin", "Kotlin", ["kt", "kts"], "https://github.com/fwcd/tree-sitter-kotlin", "TreeSitterKotlin", "tree_sitter_kotlin", "main"),
    "java": ("EditorJavaPlugin", "java", "Java", ["java"], "https://github.com/tree-sitter/tree-sitter-java.git", "TreeSitterJava", "tree_sitter_java", "master"),
    "php": ("EditorPHPPlugin", "php", "PHP", ["php"], "https://github.com/tree-sitter/tree-sitter-php.git", "TreeSitterPHP", "tree_sitter_php", "master"),
    "bash": ("EditorBashPlugin", "bash", "Bash", ["sh", "bash"], "https://github.com/tree-sitter/tree-sitter-bash.git", "TreeSitterBash", "tree_sitter_bash", "master"),
    "json": ("EditorJSONPlugin", "json", "JSON", ["json"], "https://github.com/tree-sitter/tree-sitter-json.git", "TreeSitterJSON", "tree_sitter_json", "master"),
    "yaml": ("EditorYAMLPlugin", "yaml", "YAML", ["yaml", "yml"], "https://github.com/tree-sitter-grammars/tree-sitter-yaml.git", "TreeSitterYAML", "tree_sitter_yaml", "master"),
    "toml": ("EditorTOMLPlugin", "toml", "TOML", ["toml"], "https://github.com/tree-sitter-grammars/tree-sitter-toml.git", "TreeSitterTOML", "tree_sitter_toml", "master"),
    "sql": ("EditorSQLPlugin", "sql", "SQL", ["sql"], "https://github.com/DerekStride/tree-sitter-sql", "TreeSitterSQL", "tree_sitter_sql", "main"),
    "lua": ("EditorLuaPlugin", "lua", "Lua", ["lua"], "https://github.com/tree-sitter-grammars/tree-sitter-lua", "TreeSitterLua", "tree_sitter_lua", "main"),
    "scala": ("EditorScalaPlugin", "scala", "Scala", ["scala", "sbt"], "https://github.com/tree-sitter/tree-sitter-scala.git", "TreeSitterScala", "tree_sitter_scala", "master"),
    "haskell": ("EditorHaskellPlugin", "haskell", "Haskell", ["hs", "lhs"], "https://github.com/tree-sitter/tree-sitter-haskell.git", "TreeSitterHaskell", "tree_sitter_haskell", "main"),
    "elixir": ("EditorElixirPlugin", "elixir", "Elixir", ["ex", "exs"], "https://github.com/elixir-lang/tree-sitter-elixir.git", "TreeSitterElixir", "tree_sitter_elixir", "main"),
    # Dart: vendored in EditorDartPlugin/Vendor/TreeSitterDart (remote repo has SSH submodules that break SPM)
    "dart": ("EditorDartPlugin", "dart", "Dart", ["dart"], "Vendor/TreeSitterDart", "TreeSitterDart", "tree_sitter_dart", "master"),
    "dockerfile": ("EditorDockerfilePlugin", "dockerfile", "Dockerfile", ["Dockerfile"], "https://github.com/camdencheek/tree-sitter-dockerfile.git", "TreeSitterDockerfile", "tree_sitter_dockerfile", "main"),
    "zig": ("EditorZigPlugin", "zig", "Zig", ["zig"], "https://github.com/maxxnino/tree-sitter-zig.git", "TreeSitterZig", "tree_sitter_zig", "main"),
    "agda": ("EditorAgdaPlugin", "agda", "Agda", ["agda"], "https://github.com/tree-sitter/tree-sitter-agda.git", "TreeSitterAgda", "tree_sitter_agda", "master"),
    # OCaml: vendored in EditorOCamlPlugin/Vendor/TreeSitterOCaml (upstream examples/ submodules break SPM)
    "ocaml": ("EditorOCamlPlugin", "ocaml", "OCaml", ["ml"], "Vendor/TreeSitterOCaml", "TreeSitterOCaml", "tree_sitter_ocaml", "master"),
    "julia": ("EditorJuliaPlugin", "julia", "Julia", ["jl"], "https://github.com/tree-sitter/tree-sitter-julia.git", "TreeSitterJulia", "tree_sitter_julia", "master"),
    "perl": ("EditorPerlPlugin", "perl", "Perl", ["pl", "pm"], "https://github.com/tree-sitter-perl/tree-sitter-perl.git", "TreeSitterPerl", "tree_sitter_perl", "master"),
    "regex": ("EditorRegexPlugin", "regex", "Regex", ["regex"], "https://github.com/tree-sitter/tree-sitter-regex.git", "TreeSitterRegex", "tree_sitter_regex", "master"),
    "c-sharp": ("EditorCSharpPlugin", "csharp", "C#", ["cs"], "https://github.com/tree-sitter/tree-sitter-c-sharp.git", "TreeSitterCSharp", "tree_sitter_c_sharp", "master"),
    "verilog": ("EditorVerilogPlugin", "verilog", "Verilog", ["v", "vh", "sv"], "https://github.com/tree-sitter/tree-sitter-verilog.git", "TreeSitterVerilog", "tree_sitter_verilog", "master"),
}

C_PLUGIN = {
    "c": ("EditorCPlugin", "c", "C", ["c", "h"], "https://github.com/tree-sitter/tree-sitter-c.git", "TreeSitterC", "tree_sitter_c", "master"),
}

# Additional grammars bundled into existing rich plugins (handled separately)
SKIP_GRAMMARS = {"go", "javascript", "typescript", "html", "css", "markdown", "swift", "vue", "jsx", "tsx", "jsdoc", "gomod", "markdown-inline", "objc", "cpp", "scss", "sass", "less", "ocaml-interface"}


def copy_resources(grammar_id: str, dest_plugin_sources: str) -> None:
    folder = f"tree-sitter-{grammar_id}"
    src = os.path.join(RESOURCES_SRC, folder)
    if not os.path.isdir(src):
        return
    dst = os.path.join(dest_plugin_sources, "Resources", folder)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    shutil.copytree(src, dst)


def write_package(plugin_name: str, spm_url: str, spm_product: str) -> str:
    module = plugin_name
    return textwrap.dedent(
        f"""
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "{module}",
            defaultLocalization: "en",
            platforms: [.macOS(.v14)],
            products: [
                .library(name: "{module}", targets: ["{module}"])
            ],
            dependencies: [
                .package(path: "../../Packages/EditorService"),
                .package(path: "../../Packages/LumiCoreKit"),
                .package(url: "{spm_url}", branch: "master"),
            ],
            targets: [
                .target(
                    name: "{module}",
                    dependencies: [
                        .product(name: "EditorService", package: "EditorService"),
                        .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                        .product(name: "{spm_product}", package: "{spm_url.split('/')[-1].replace('.git', '')}"),
                    ],
                    path: "Sources",
                    resources: [.copy("Resources")]
                ),
                .testTarget(
                    name: "{module}Tests",
                    dependencies: ["{module}"],
                    path: "Tests"
                ),
            ]
        )
        """
    ).strip() + "\n"


def write_plugin(
    plugin_name: str,
    language_id: str,
    display_name: str,
    extensions: list[str],
    grammar_id: str,
    tree_sitter_fn: str,
) -> None:
    plugin_dir = os.path.join(PLUGINS, plugin_name)
    sources = os.path.join(plugin_dir, "Sources")
    os.makedirs(sources, exist_ok=True)
    os.makedirs(os.path.join(plugin_dir, "Tests"), exist_ok=True)

    ext_literal = ", ".join(f'"{e}"' for e in extensions)
    actor_name = plugin_name.replace("Plugin", "Plugin")

    plugin_swift = textwrap.dedent(
        f"""
        import EditorService
        import LumiCoreKit
        import TreeSitter{grammar_id.replace('-', '').title().replace('_', '') if False else ''}

        public actor {plugin_name}: SuperPlugin {{
            public nonisolated static let policy: LumiPluginPolicy = .optIn
            public static let shared = {plugin_name}()
            public static let id = "{language_id.capitalize()}Highlight"
            public static let displayName = "{display_name} Highlight"
            public static let description = "Syntax highlighting and language detection for {display_name}."
            public static let iconName = "chevron.left.forwardslash.chevron.right"
            public static let order = 200
            public static var category: LumiPluginCategory {{ .editor }}
            public nonisolated var providesEditorExtensions: Bool {{ true }}

            @MainActor
            public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {{
                guard let registry = registry as? EditorExtensionRegistry else {{ return }}
                registry.registerLanguage({plugin_name}Descriptor.descriptor)
                registry.registerGrammarProvider({plugin_name}GrammarProvider())
            }}
        }}
        """
    )

    # Fix import - use dynamic product name from LANGUAGES tuple
    pass


def main() -> None:
    for grammar_id, spec in {**LANGUAGES, **C_PLUGIN}.items():
        if grammar_id in SKIP_GRAMMARS:
            continue
        plugin_name, language_id, display_name, extensions, spm_url, spm_product, ts_fn, branch = spec
        plugin_dir = os.path.join(PLUGINS, plugin_name)
        sources = os.path.join(plugin_dir, "Sources")
        os.makedirs(sources, exist_ok=True)
        os.makedirs(os.path.join(plugin_dir, "Tests"), exist_ok=True)

        copy_resources(grammar_id, sources)

        pkg_name = spm_url.rstrip("/").split("/")[-1].replace(".git", "")
        package_swift = f"""// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "{plugin_name}",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [.library(name: "{plugin_name}", targets: ["{plugin_name}"])],
    dependencies: [
        .package(path: "../../Packages/EditorService"),
        .package(path: "../../Packages/LumiCoreKit"),
        .package(url: "{spm_url}", branch: "{branch}"),
    ],
    targets: [
        .target(
            name: "{plugin_name}",
            dependencies: [
                .product(name: "EditorService", package: "EditorService"),
                .product(name: "LumiCoreKit", package: "LumiCoreKit"),
                .product(name: "{spm_product}", package: "{pkg_name}"),
            ],
            path: "Sources",
            resources: [.copy("Resources")]
        ),
        .testTarget(name: "{plugin_name}Tests", dependencies: ["{plugin_name}"], path: "Tests"),
    ]
)
"""
        with open(os.path.join(plugin_dir, "Package.swift"), "w") as f:
            f.write(package_swift)

        ext_set = ", ".join(f'"{e}"' for e in extensions)
        descriptor_swift = f"""import EditorService

enum {plugin_name}Descriptor {{
    static let descriptor = EditorLanguageDescriptor(
        languageId: "{language_id}",
        displayName: "{display_name}",
        fileExtensions: [{ext_set}],
        lineComment: "//",
        highlightLanguageId: "{grammar_id}"
    )
}}
"""
        grammar_swift = f"""import EditorService
import {spm_product}

final class {plugin_name}GrammarProvider: BundledGrammarProvider {{
    init() {{
        super.init(
            grammarId: "{grammar_id}",
            bundle: .module,
            languagePointer: {{ {ts_fn}() }}
        )
    }}
}}
"""
        plugin_swift = f"""import EditorService
import LumiCoreKit

public actor {plugin_name}: SuperPlugin {{
    public nonisolated static let policy: PluginPolicy = .optIn
    public static let shared = {plugin_name}()
    public static let id = "{language_id}Highlight"
    public static let displayName = "{display_name} Highlight"
    public static let description = "Syntax highlighting and language detection for {display_name}."
    public static let iconName = "chevron.left.forwardslash.chevron.right"
    public static let order = 200
    public static var category: LumiPluginCategory {{ .editor }}
    public nonisolated var providesEditorExtensions: Bool {{ true }}

    @MainActor
    public func registerEditorExtensions(into registry: any EditorExtensionRegistryProtocol) {{
        guard let registry = registry as? EditorExtensionRegistry else {{ return }}
        registry.registerLanguage({plugin_name}Descriptor.descriptor)
        registry.registerGrammarProvider({plugin_name}GrammarProvider())
    }}
}}
"""
        registering = f"""import EditorService
import LumiCoreKit

extension {plugin_name}: LumiEditorExtensionRegistering {{
    public static var extensionPluginInfo: LumiPluginInfo {{
        LumiPluginInfo(id: id, displayName: displayName, description: description, order: order)
    }}
    public static var extensionPluginPolicy: LumiPluginPolicy { policy }
    @MainActor
    public static func registerEditorExtensionsErased(into registry: AnyObject) async {{
        guard let registry = registry as? EditorExtensionRegistry else {{ return }}
        await shared.registerEditorExtensions(into: registry)
    }}
}}
"""
        for name, content in [
            (f"{plugin_name}.swift", plugin_swift),
            (f"{plugin_name}Descriptor.swift", descriptor_swift),
            (f"{plugin_name}GrammarProvider.swift", grammar_swift),
            ("LumiEditorExtensionRegistering.swift", registering),
        ]:
            with open(os.path.join(sources, name), "w") as f:
                f.write(content)

        print(f"Generated {plugin_name}")


if __name__ == "__main__":
    main()
