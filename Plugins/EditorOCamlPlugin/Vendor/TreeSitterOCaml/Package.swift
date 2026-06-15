// swift-tools-version: 5.6
import PackageDescription

let package = Package(
    name: "TreeSitterOCaml",
    products: [
        .library(name: "TreeSitterOCaml", targets: ["TreeSitterOCaml"]),
    ],
    targets: [
        .target(
            name: "TreeSitterOCaml",
            path: ".",
            sources: [
                "grammars/ocaml/src/parser.c",
                "grammars/ocaml/src/scanner.c",
                "grammars/interface/src/parser.c",
                "grammars/interface/src/scanner.c",
                "grammars/type/src/parser.c",
                "grammars/type/src/scanner.c",
            ],
            resources: [
                .copy("queries"),
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("grammars/ocaml/src")]
        ),
    ],
    cLanguageStandard: .c11
)
