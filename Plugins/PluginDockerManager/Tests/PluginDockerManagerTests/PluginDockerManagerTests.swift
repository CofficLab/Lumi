import Testing
import DockerKit
import LumiCoreKit
@testable import PluginDockerManager

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
        #expect(DockerManagerPlugin.policy == .alwaysOn)
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

private actor FakeDockerManagerService: DockerManagerServicing {
    let delays: [String: UInt64]

    init(delays: [String: UInt64]) {
        self.delays = delays
    }

    func listImages() async throws -> [DockerImage] {
        []
    }

    func removeImage(_ id: String, force: Bool) async throws {}

    func pullImage(_ name: String) async throws -> String {
        ""
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

    func tagImage(_ id: String, target: String) async throws {}

    func exportImage(_ id: String, to path: String) async throws {}

    func loadImage(from path: String) async throws {}

    func scanImage(_ id: String) async throws -> String {
        ""
    }
}
