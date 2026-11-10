import Foundation
import Testing
@testable import DockerManagerPlugin

@MainActor
struct PluginDockerManagerTests {
    @Test
    func pluginMetadataIsStable() {
        let plugin = DockerManagerPlugin()
        #expect(plugin.id == "com.coffic.lumi.plugin.docker-manager")
        #expect(plugin.metadata.name == "Docker")
        #expect(plugin.order == 50)
        #expect(plugin.metadata.policy == .disabled)
    }

    @Test
    func v2IdentifiersRemainStable() {
        #expect(DockerManagerPlugin().id.hasSuffix("docker-manager"))
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

    @Test
    func failedExportKeepsExistingDestinationAndCleansTemporaryFile() async throws {
        let image = Self.image(id: "sha256:test", repository: "test")
        let service = FakeDockerManagerService()
        await service.setExportBehavior(.writeThenFail(Data("partial tarball".utf8)))
        let viewModel = DockerManagerViewModel(service: service)

        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("image.tar")
        let original = Data("original tarball".utf8)
        try original.write(to: destination)

        let succeeded = await viewModel.exportImage(image, to: destination)

        #expect(succeeded == false)
        #expect(try Data(contentsOf: destination) == original)
        #expect(viewModel.errorMessage?.hasPrefix("Export failed:") == true)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["image.tar"])
    }

    @Test
    func successfulExportAtomicallyReplacesExistingDestination() async throws {
        let image = Self.image(id: "sha256:test", repository: "test")
        let service = FakeDockerManagerService()
        let exported = Data("fresh tarball".utf8)
        await service.setExportBehavior(.succeed(exported))
        let viewModel = DockerManagerViewModel(service: service)

        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("image.tar")
        try Data("stale tarball".utf8).write(to: destination)

        let succeeded = await viewModel.exportImage(image, to: destination)

        #expect(succeeded == true)
        #expect(viewModel.errorMessage == nil)
        #expect(try Data(contentsOf: destination) == exported)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["image.tar"])
    }

    @Test
    func exportWithoutOutputFileReportsFailureAndRemovesNothingElse() async throws {
        let image = Self.image(id: "sha256:test", repository: "test")
        let service = FakeDockerManagerService()
        await service.setExportBehavior(.succeedWithoutWriting)
        let viewModel = DockerManagerViewModel(service: service)

        let directory = Self.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appendingPathComponent("image.tar")

        let succeeded = await viewModel.exportImage(image, to: destination)

        #expect(succeeded == false)
        #expect(viewModel.errorMessage?.contains("no output file") == true)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    private static func temporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("docker-export-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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

private struct FakeExportFailure: Error {}

private actor FakeDockerManagerService: DockerManagerServicing {
    enum ExportBehavior: Sendable {
        case fail
        case succeed(Data)
        case succeedWithoutWriting
        case writeThenFail(Data)
    }

    let delays: [String: UInt64]
    private var pullRequests: [String] = []
    private var tagRequests: [TaggedImage] = []
    private var exportBehavior: ExportBehavior = .fail

    init(delays: [String: UInt64] = [:]) {
        self.delays = delays
    }

    func setExportBehavior(_ behavior: ExportBehavior) {
        exportBehavior = behavior
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

    func exportImage(_ id: String, to path: String) async throws {
        switch exportBehavior {
        case .fail:
            throw FakeExportFailure()
        case .succeedWithoutWriting:
            break
        case let .succeed(data):
            try data.write(to: URL(fileURLWithPath: path))
        case let .writeThenFail(data):
            try data.write(to: URL(fileURLWithPath: path))
            throw FakeExportFailure()
        }
    }

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
