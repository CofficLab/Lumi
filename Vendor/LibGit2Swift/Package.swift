// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LibGit2Swift",
    platforms: [
        .macOS("13.1")
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LibGit2Swift",
            targets: ["LibGit2Swift"]),
    ],
    dependencies: [
        .package(path: "../MagicLog"),
    ],
    targets: [
        // Binary target for libgit2 - built from Scripts/build-libgit2-framework.sh
        .binaryTarget(
            name: "Clibgit2",
            path: "Sources/Clibgit2.xcframework"
        ),
        // Targets are the basic building blocks of a package. A target can define a module or test suite.
        // Targets can depend on on targets in this package, or on products of packages this package depends on.
        .target(
            name: "LibGit2Swift",
            dependencies: [
                "Clibgit2",  // Local binary target instead of external package
                .product(name: "MagicLog", package: "MagicLog"),
            ],
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("iconv")
            ]
        ),
        .testTarget(
            name: "LibGit2SwiftTests",
            dependencies: ["LibGit2Swift"])
    ]
)
