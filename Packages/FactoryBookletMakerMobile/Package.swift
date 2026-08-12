// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FactoryBookletMakerMobile",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FactoryBookletMakerMobile", targets: ["FactoryBookletMakerMobile"]),
    ],
    dependencies: [
        .package(path: "../FactoryCoreMobile"),
        .package(path: "../../Plugins/StoragePlugin"),
        .package(path: "../../Plugins/WorkspacePlugin"),
        .package(path: "../../Plugins/SettingsPlugin"),
        .package(path: "../../Plugins/LogoPlugin"),
        .package(path: "../../Plugins/ThemeManagerPlugin"),
        .package(path: "../../Plugins/ThemeLumiPlugin"),
        .package(path: "../../Plugins/BookletMakerPlugin"),
    ],
    targets: [
        .target(
            name: "FactoryBookletMakerMobile",
            dependencies: [
                .product(name: "FactoryCoreMobile", package: "FactoryCoreMobile"),
                .product(name: "StoragePlugin", package: "StoragePlugin"),
                .product(name: "WorkspacePlugin", package: "WorkspacePlugin"),
                .product(name: "SettingsPlugin", package: "SettingsPlugin"),
                .product(name: "LogoPlugin", package: "LogoPlugin"),
                .product(name: "ThemeManagerPlugin", package: "ThemeManagerPlugin"),
                .product(name: "ThemeLumiPlugin", package: "ThemeLumiPlugin"),
                .product(name: "BookletMakerPlugin", package: "BookletMakerPlugin"),
            ]
        )
    ]
)
