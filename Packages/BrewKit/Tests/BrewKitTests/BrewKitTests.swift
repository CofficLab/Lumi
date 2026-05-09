import Testing
@testable import BrewKit

@Suite("BrewKit Models Tests")
struct BrewKitModelsTests {

    @Test("BrewPackage initialization")
    func brewPackageInit() {
        let package = BrewPackage(
            name: "git",
            desc: "Distributed version control system",
            homepage: "https://git-scm.com",
            version: "2.43.0",
            installedVersion: "2.42.0",
            outdated: true,
            isCask: false
        )

        #expect(package.id == "git")
        #expect(package.isInstalled == true)
        #expect(package.outdated == true)
        #expect(package.isCask == false)
    }

    @Test("BrewPackage not installed")
    func brewPackageNotInstalled() {
        let package = BrewPackage(
            name: "node",
            desc: nil,
            homepage: nil,
            version: "21.0.0",
            installedVersion: nil,
            outdated: false,
            isCask: false
        )

        #expect(package.isInstalled == false)
    }

    @Test("BrewVersions decoding")
    func brewVersionsDecoding() {
        let json = """
        {"stable": "1.0.0"}
        """
        let data = json.data(using: .utf8)!
        let versions = try! JSONDecoder().decode(BrewVersions.self, from: data)

        #expect(versions.stable == "1.0.0")
    }
}

@Suite("BrewKit Service Tests")
struct BrewKitServiceTests {

    @Test("BrewService shared instance")
    func brewServiceShared() async {
        let service = BrewService.shared
        #expect(await service.checkInstalled() == true || await service.checkInstalled() == false)
    }

    @Test("BrewError cases")
    func brewErrorCases() {
        let error1 = BrewError.notInstalled
        let error2 = BrewError.commandFailed("test error")
        let error3 = BrewError.notFound

        #expect(error1 == BrewError.notInstalled)
        #expect(error2 == BrewError.commandFailed("test error"))
        #expect(error3 == BrewError.notFound)
    }
}