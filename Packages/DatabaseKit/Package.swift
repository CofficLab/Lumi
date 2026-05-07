// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DatabaseKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DatabaseKit",
            targets: ["DatabaseKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/mysql-nio", from: "1.9.0"),
        .package(url: "https://github.com/vapor/postgres-nio", from: "1.30.1"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "DatabaseKit",
            dependencies: [
                .product(name: "MySQLNIO", package: "mysql-nio"),
                .product(name: "PostgresNIO", package: "postgres-nio"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log")
            ]
        ),
        .testTarget(
            name: "DatabaseKitTests",
            dependencies: ["DatabaseKit"]
        )
    ]
)
