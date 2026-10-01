// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KitMail",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "KitMail",
            targets: ["KitMail"]
        )
    ],
    dependencies: [
        // MailCore2 以 vendored xcframework 引入（本地 binary target），
        // 见 docs/plans/2026-10-01-mail-client-plugin.md 第 4 节 Spike 结论。
        // 官方 SPM binary 仅含 macos-x86_64，不适用于 Apple Silicon，
        // 因此由本地构建产物提供 macos-arm64 slice。
    ],
    targets: [
        .target(
            name: "KitMail",
            dependencies: [
                .target(name: "MailCore2"),
            ],
            path: ".",
            exclude: ["Tests", "Vendor", "README.md"],
            sources: ["Sources"]
        ),
        .binaryTarget(
            name: "MailCore2",
            path: "Vendor/MailCore2.xcframework"
        ),
        .testTarget(
            name: "KitMailTests",
            dependencies: ["KitMail", "MailCore2"],
            path: "Tests"
        )
    ]
)
