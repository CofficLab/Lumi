// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TreeSitterDart",
    products: [
        .library(name: "TreeSitterDart", targets: ["TreeSitterDart"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TreeSitterDart",
            path: ".",
            sources: [
                "src/parser.c",
                "src/scanner.c",
            ],
            resources: [
                .copy("queries"),
            ],
            publicHeadersPath: "bindings/swift",
            cSettings: [.headerSearchPath("src")]
        ),
    ],
    cLanguageStandard: .c11
)
