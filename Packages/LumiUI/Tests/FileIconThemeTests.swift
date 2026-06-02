import Foundation
import Testing
@testable import LumiUI

struct FileIconThemeTests {
    @Test
    func swiftPackageDirectoryUsesPackageIcon() {
        let contributor = LumiDefaultFileIconThemeContributor()
        let url = URL(fileURLWithPath: "/tmp/ExamplePackage", isDirectory: true)

        let collapsed = contributor.icon(for: LumiFileIconContext(
            url: url,
            fileName: "ExamplePackage",
            fileExtension: "",
            isDirectory: true,
            isExpanded: false,
            isSwiftPackageDirectory: true,
            projectRootPath: "/tmp"
        ))
        let expanded = contributor.icon(for: LumiFileIconContext(
            url: url,
            fileName: "ExamplePackage",
            fileExtension: "",
            isDirectory: true,
            isExpanded: true,
            isSwiftPackageDirectory: true,
            projectRootPath: "/tmp"
        ))

        #expect(systemImageName(collapsed) == "shippingbox")
        #expect(systemImageName(expanded) == "shippingbox.fill")
    }

    @Test
    func regularDirectoryFallsBackToFolderIcon() {
        let contributor = LumiDefaultFileIconThemeContributor()
        let url = URL(fileURLWithPath: "/tmp/Regular", isDirectory: true)

        let icon = contributor.icon(for: LumiFileIconContext(
            url: url,
            fileName: "Regular",
            fileExtension: "",
            isDirectory: true,
            isExpanded: false,
            projectRootPath: "/tmp"
        ))

        #expect(icon == nil)
    }

    @Test
    func customExtensionIconsTolerateCaseInsensitiveDuplicates() {
        let contributor = LumiFileIconThemeBuilder.make(
            id: "custom",
            displayName: "Custom",
            defaultFile: .systemImage("doc"),
            defaultFolder: LumiFolderFileIcon(
                collapsed: .systemImage("folder"),
                expanded: .systemImage("folder.fill")
            ),
            extraExtensions: [
                "LUMI": .systemImage("doc.badge.gearshape"),
                "lumi": .systemImage("doc.badge.ellipsis"),
            ]
        )

        let icon = contributor.icon(for: LumiFileIconContext(
            url: URL(fileURLWithPath: "/tmp/example.LUMI"),
            fileName: "example.LUMI",
            fileExtension: "LUMI",
            isDirectory: false,
            isExpanded: false,
            projectRootPath: "/tmp"
        ))

        #expect([
            "doc.badge.gearshape",
            "doc.badge.ellipsis",
        ].contains(systemImageName(icon)))
    }

    @Test
    func customFolderIconsTolerateCaseInsensitiveDuplicates() {
        let contributor = LumiFileIconThemeBuilder.make(
            id: "custom",
            displayName: "Custom",
            defaultFile: .systemImage("doc"),
            defaultFolder: LumiFolderFileIcon(
                collapsed: .systemImage("folder"),
                expanded: .systemImage("folder.fill")
            ),
            extraFolders: [
                "Config": LumiFileIconThemeBuilder.folder("gearshape", "gearshape.fill"),
                "config": LumiFileIconThemeBuilder.folder("slider.horizontal.3", "slider.horizontal.3"),
            ]
        )

        let icon = contributor.icon(for: LumiFileIconContext(
            url: URL(fileURLWithPath: "/tmp/Config", isDirectory: true),
            fileName: "Config",
            fileExtension: "",
            isDirectory: true,
            isExpanded: false,
            projectRootPath: "/tmp"
        ))

        #expect([
            "gearshape",
            "slider.horizontal.3",
        ].contains(systemImageName(icon)))
    }

    private func systemImageName(_ icon: LumiFileIcon?) -> String? {
        guard case let .some(.systemImage(name)) = icon else { return nil }
        return name
    }
}
