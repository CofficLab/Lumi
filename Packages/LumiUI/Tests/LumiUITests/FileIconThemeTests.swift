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

    private func systemImageName(_ icon: LumiFileIcon?) -> String? {
        guard case let .some(.systemImage(name)) = icon else { return nil }
        return name
    }
}
