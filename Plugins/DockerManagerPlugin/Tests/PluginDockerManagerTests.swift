import Testing
import LumiKernel
@testable import DockerManagerPlugin

@MainActor
struct PluginDockerManagerTests {
    @Test
    func pluginMetadataIsStable() {
        #expect(DockerManagerPlugin.id == "DockerManager")
        #expect(DockerManagerPlugin.navigationId == "docker_manager")
        #expect(DockerManagerPlugin.displayName.isEmpty == false)
        #expect(DockerManagerPlugin.description.isEmpty == false)
        #expect(DockerManagerPlugin.iconName == "shippingbox")
        #expect(DockerManagerPlugin.category == .developerTool)
        #expect(DockerManagerPlugin.order == 50)
        #expect(DockerManagerPlugin.policy == .disabled)
        #expect(DockerManagerPlugin.shared.instanceLabel == DockerManagerPlugin.id)
    }

    @Test
    func viewContainerContributionIsAvailable() {
        let item = DockerManagerPlugin.shared.addViewContainer()
        #expect(item?.id == DockerManagerPlugin.id)
        #expect(item?.title == DockerManagerPlugin.displayName)
        #expect(item?.icon == DockerManagerPlugin.iconName)
    }

    @Test
    func localizationCatalogIsPackaged() {
        #expect(PluginDockerManagerLocalization.bundle.url(forResource: "DockerManager", withExtension: "xcstrings") != nil)
        #expect(PluginDockerManagerLocalization.string("Docker").isEmpty == false)
    }

    @Test
    func selectingAnotherImageIgnoresStaleDetails() async throws {
        let slowImage = Self.image(id: "sha256:slow", repository: "slow")
        let fastImage = Self.image(id: "sha256:fast", repository: "fast")
        let service = FakeDockerManagerService(delays: [
            slowImage.imageID: 200_000_000,
            fastImage.imageID: 10_000_000,
        ])
        let viewModel = DockerManagerViewModel(service: service)

        let firstSelection = Task {
            await viewModel.selectImage(slowImage)
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        await viewModel.selectImage(fastImage)
        await firstSelection.value

        #expect(viewModel.selectedImage?.imageID == fastImage.imageID)
        #expect(viewModel.selectedImageDetail?.Id == fastImage.imageID)
        #expect(viewModel.selectedImageHistory.first?.Comment == fastImage.imageID)
        #expect(viewModel.errorMessage == nil)
    }

    @Test
    func pullImageRejectsInvalidReferencesBeforeCallingDocker() async {
        let service = FakeDockerManagerService()
        let viewModel = DockerManagerViewModel(service: service)

        #expect(await viewModel.pullImage("--help") == false)
        #expect(viewModel.errorMessage == "Invalid image name")
        #expect(await service.pulledImages() == [])

        #expect(await viewModel.pullImage("  registry.example.com/ns/app:V1  ") == true)
        #expect(await service.pulledImages() == ["registry.example.com/ns/app:V1"])
    }

    @Test
    func tagImageRejectsInvalidReferencesBeforeCallingDocker() async {
        let image = Self.image(id: "sha256:test", repository: "test")
        let service = FakeDockerManagerService()
        let viewModel = DockerManagerViewModel(service: service)

        #expect(await viewModel.tagImage(image, newTag: "repo/name:bad tag") == false)
        #expect(viewModel.errorMessage == "Invalid image tag")
        #expect(await service.taggedImages() == [])

        #expect(await viewModel.tagImage(image, newTag: "  repo/name:Release_1  ") == true)
        #expect(await service.taggedImages() == [TaggedImage(id: image.imageID, target: "repo/name:Release_1")])
    }

    private static func image(id: String, repository: String) -> DockerImage {
        DockerImage(
            imageID: id,
            repository: repository,
            tag: "latest",
            createdAt: "2026-01-01 00:00:00 +0000 UTC",
            createdSince: "1 day ago",
            size: "1 MB",
            virtualSize: "1 MB",
            digest: ""
        )
    }
}

private struct TaggedImage: Equatable, Sendable {
    let id: String
    let target: String
}

private actor FakeDockerManagerService: DockerManagerServicing {
    let delays: [String: UInt64]
    private var pullRequests: [String] = []
    private var tagRequests: [TaggedImage] = []

    init(delays: [String: UInt64] = [:]) {
        self.delays = delays
    }

    func listImages() async throws -> [DockerImage] {
        []
    }

    func removeImage(_ id: String, force: Bool) async throws {}

    func pullImage(_ name: String) async throws -> String {
        pullRequests.append(name)
        return ""
    }

    func inspectImage(_ id: String) async throws -> DockerInspect {
        if let delay = delays[id] {
            try? await Task.sleep(nanoseconds: delay)
        }
        return DockerInspect(
            Id: id,
            RepoTags: nil,
            Architecture: "arm64",
            Os: "linux",
            Size: nil,
            VirtualSize: nil,
            Author: nil,
            Config: nil
        )
    }

    func getImageHistory(_ id: String) async throws -> [DockerImageHistory] {
        if let delay = delays[id] {
            try? await Task.sleep(nanoseconds: delay)
        }
        return [
            DockerImageHistory(
                Created: 0,
                CreatedBy: "test",
                Size: "0 B",
                Comment: id
            )
        ]
    }

    func tagImage(_ id: String, target: String) async throws {
        tagRequests.append(TaggedImage(id: id, target: target))
    }

    func exportImage(_ id: String, to path: String) async throws {}

    func loadImage(from path: String) async throws {}

    func scanImage(_ id: String) async throws -> String {
        ""
    }

    func pulledImages() -> [String] {
        pullRequests
    }

    func taggedImages() -> [TaggedImage] {
        tagRequests
    }
}
