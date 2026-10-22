import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import Testing
@testable import DockerManagerPlugin

// MARK: - 测试替身

/// 可编程的 Docker 服务替身。
private actor StubDockerService: DockerManagerServicing {
    var images: [DockerImage] = []
    var inspectResult: DockerInspect?
    var historyResult: [DockerImageHistory] = []
    var scanResult = "scan output"
    var listError: Error?
    var removeError: Error?
    var pullError: Error?
    var tagError: Error?
    var exportError: Error?
    var loadError: Error?
    var scanError: Error?

    private(set) var removedImages: [(id: String, force: Bool)] = []
    private(set) var pulledImages: [String] = []
    private(set) var taggedImages: [(id: String, target: String)] = []
    private(set) var exportedImages: [(id: String, path: String)] = []
    private(set) var loadedPaths: [String] = []
    private(set) var scannedImages: [String] = []

    func listImages() async throws -> [DockerImage] {
        if let listError { throw listError }
        return images
    }

    func removeImage(_ id: String, force: Bool) async throws {
        removedImages.append((id, force))
        if let removeError { throw removeError }
    }

    func pullImage(_ name: String) async throws -> String {
        pulledImages.append(name)
        if let pullError { throw pullError }
        return "pulled"
    }

    func inspectImage(_ id: String) async throws -> DockerInspect {
        guard let inspectResult else {
            throw DockerError.parsingFailed("no data")
        }
        return inspectResult
    }

    func getImageHistory(_ id: String) async throws -> [DockerImageHistory] {
        historyResult
    }

    func tagImage(_ id: String, target: String) async throws {
        taggedImages.append((id, target))
        if let tagError { throw tagError }
    }

    func exportImage(_ id: String, to path: String) async throws {
        exportedImages.append((id, path))
        if let exportError { throw exportError }
    }

    func loadImage(from path: String) async throws {
        loadedPaths.append(path)
        if let loadError { throw loadError }
    }

    func scanImage(_ id: String) async throws -> String {
        scannedImages.append(id)
        if let scanError { throw scanError }
        return scanResult
    }

    // MARK: Test driving

    func setImages(_ value: [DockerImage]) { images = value }
    func setInspectResult(_ value: DockerInspect?) { inspectResult = value }
    func setListError(_ value: Error?) { listError = value }
    func setRemoveError(_ value: Error?) { removeError = value }
    func setTagError(_ value: Error?) { tagError = value }
    func setExportError(_ value: Error?) { exportError = value }
    func setLoadError(_ value: Error?) { loadError = value }
    func setScanError(_ value: Error?) { scanError = value }
}

// MARK: - 模型

@Suite("Docker 镜像模型")
struct DockerModelTests {

    @Test("十进制单位换算正确")
    func parsesDecimalUnits() {
        #expect(DockerImage.parseSizeBytes("1 B") == 1)
        #expect(DockerImage.parseSizeBytes("1 KB") == 1_000)
        #expect(DockerImage.parseSizeBytes("1 MB") == 1_000_000)
        #expect(DockerImage.parseSizeBytes("1 GB") == 1_000_000_000)
        #expect(DockerImage.parseSizeBytes("1 TB") == 1_000_000_000_000)
    }

    @Test("二进制单位换算正确")
    func parsesBinaryUnits() {
        #expect(DockerImage.parseSizeBytes("1 KiB") == 1_024)
        #expect(DockerImage.parseSizeBytes("1 MiB") == 1_048_576)
        #expect(DockerImage.parseSizeBytes("1 GiB") == 1_073_741_824)
        #expect(DockerImage.parseSizeBytes("1 TiB") == 1_099_511_627_776)
    }

    @Test("小数与空白被正确处理")
    func parsesFractionalAndSpacedValues() {
        #expect(DockerImage.parseSizeBytes("1.5 KB") == 1_500)
        #expect(DockerImage.parseSizeBytes("  2 MB  ") == 2_000_000)
        #expect(DockerImage.parseSizeBytes("1mb") == 1_000_000)
    }

    @Test("无法识别的体积返回 0")
    func rejectsUnparsableSizes() {
        #expect(DockerImage.parseSizeBytes("") == 0)
        #expect(DockerImage.parseSizeBytes("   ") == 0)
        #expect(DockerImage.parseSizeBytes("unknown") == 0)
        #expect(DockerImage.parseSizeBytes("12") == 0)
        #expect(DockerImage.parseSizeBytes("1 PB") == 0)
    }

    @Test("名称在仓库缺失时回退到短 ID")
    func nameFallsBackToShortID() {
        let unnamed = DockerImage(
            imageID: "sha256:0123456789abcdef",
            repository: "<none>",
            tag: "<none>",
            createdAt: "",
            createdSince: "",
            size: "1 B",
            virtualSize: "1 B",
            digest: ""
        )
        let named = DockerImage(
            imageID: "sha256:0123456789abcdef",
            repository: "ubuntu",
            tag: "22.04",
            createdAt: "",
            createdSince: "",
            size: "1 B",
            virtualSize: "1 B",
            digest: ""
        )

        #expect(unnamed.name == "0123456789ab")
        #expect(named.name == "ubuntu:22.04")
    }

    @Test("短 ID 去掉 sha256 前缀并截断到 12 位")
    func shortIDTruncates() {
        let image = DockerImage(
            imageID: "sha256:0123456789abcdefghij",
            repository: "ubuntu",
            tag: "latest",
            createdAt: "",
            createdSince: "",
            size: "2 MB",
            virtualSize: "2 MB",
            digest: ""
        )

        #expect(image.shortID == "0123456789ab")
        #expect(image.sizeBytes == 2_000_000)
    }

    @Test("镜像可编解码且缺省 digest 视为空串")
    func imageRoundTripsThroughCodable() throws {
        let image = DockerImage(
            imageID: "sha256:abc",
            repository: "ubuntu",
            tag: "latest",
            createdAt: "2026-01-01",
            createdSince: "1 day ago",
            size: "1 MB",
            virtualSize: "2 MB",
            digest: "sha256:def"
        )

        let data = try JSONEncoder().encode(image)
        let decoded = try JSONDecoder().decode(DockerImage.self, from: data)

        #expect(decoded == image)
        #expect(decoded.id == image.imageID)
    }

    @Test("缺少 Digest 字段时解码得到空串")
    func decodesImageWithoutDigest() throws {
        let json = """
        {"ID":"sha256:abc","Repository":"ubuntu","Tag":"latest","CreatedAt":"2026-01-01",\
        "CreatedSince":"1 day ago","Size":"1 MB","VirtualSize":"2 MB"}
        """

        let decoded = try JSONDecoder().decode(
            DockerImage.self,
            from: Data(json.utf8)
        )

        #expect(decoded.digest == "")
    }

    @Test("历史记录的 Size 为数字时转成可读字符串")
    func decodesHistoryWithNumericSize() throws {
        let json = """
        {"Created":1700000000,"CreatedBy":"RUN apt-get","Size":1048576,"Comment":"c"}
        """

        let decoded = try JSONDecoder().decode(DockerImageHistory.self, from: Data(json.utf8))

        #expect(decoded.Created == 1_700_000_000)
        #expect(decoded.CreatedBy == "RUN apt-get")
        #expect(decoded.Size.isEmpty == false)
        #expect(decoded.Comment == "c")
    }

    @Test("历史记录的 Size 为字符串时原样保留")
    func decodesHistoryWithStringSize() throws {
        let json = """
        {"Created":1,"CreatedBy":"RUN","Size":"1 MB","Comment":"c"}
        """

        let decoded = try JSONDecoder().decode(DockerImageHistory.self, from: Data(json.utf8))

        #expect(decoded.Size == "1 MB")
    }

    @Test("错误描述覆盖三种情况")
    func errorDescriptionsAreInformative() {
        #expect(DockerError.commandFailed("boom").errorDescription?.contains("boom") == true)
        #expect(DockerError.parsingFailed("bad").errorDescription?.contains("bad") == true)
        #expect(DockerError.dockerNotFound.errorDescription?.isEmpty == false)
    }
}

// MARK: - 引用校验

@Suite("Docker 镜像引用校验")
struct DockerImageReferenceValidatorTests {

    @Test("合法引用通过校验")
    func acceptsValidReferences() {
        #expect(DockerImageReferenceValidator.isValidReference("ubuntu:22.04"))
        #expect(DockerImageReferenceValidator.isValidReference("registry.example.com/ns/app:V1"))
        #expect(DockerImageReferenceValidator.isValidReference("repo/name@sha256:abc"))
    }

    @Test("首尾空白被裁剪")
    func trimsWhitespace() {
        let normalized = DockerImageReferenceValidator.normalizedReference("  ubuntu:22.04  ")

        #expect(normalized == "ubuntu:22.04")
    }

    @Test("空引用被拒绝")
    func rejectsEmptyReference() {
        #expect(DockerImageReferenceValidator.normalizedReference("") == nil)
        #expect(DockerImageReferenceValidator.normalizedReference("   ") == nil)
    }

    @Test("超长引用被拒绝")
    func rejectsOverlongReference() {
        let long = String(repeating: "a", count: 256)

        #expect(DockerImageReferenceValidator.normalizedReference(long) == nil)
    }

    @Test("以连字符开头的引用被拒绝")
    func rejectsLeadingDash() {
        #expect(DockerImageReferenceValidator.normalizedReference("--help") == nil)
    }

    @Test("含非法字符的引用被拒绝")
    func rejectsIllegalCharacters() {
        #expect(DockerImageReferenceValidator.normalizedReference("repo/name:bad tag") == nil)
        #expect(DockerImageReferenceValidator.normalizedReference("repo/name!") == nil)
    }

    @Test("含空路径段的引用被拒绝")
    func rejectsEmptyPathSegment() {
        #expect(DockerImageReferenceValidator.normalizedReference("repo//name") == nil)
    }
}

// MARK: - ViewModel

@Suite("Docker ViewModel")
@MainActor
struct DockerManagerViewModelTests {

    @Test("刷新成功后填充镜像列表")
    func refreshFillsImages() async {
        let service = StubDockerService()
        await service.setImages([Self.image(id: "sha256:a", repository: "alpha", size: "1 MB")])
        let viewModel = DockerManagerViewModel(service: service)

        await viewModel.refreshImages()

        #expect(viewModel.images.count == 1)
        #expect(viewModel.filteredImages.count == 1)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("刷新失败时记录错误信息")
    func refreshReportsError() async {
        let service = StubDockerService()
        await service.setListError(DockerError.dockerNotFound)
        let viewModel = DockerManagerViewModel(service: service)

        await viewModel.refreshImages()

        #expect(viewModel.errorMessage?.isEmpty == false)
        #expect(viewModel.isLoading == false)
    }

    @Test("删除镜像后从列表移除并清空选中详情")
    func deleteRemovesImage() async {
        let image = Self.image(id: "sha256:a", repository: "alpha")
        let service = StubDockerService()
        await service.setImages([image])
        await service.setInspectResult(
            DockerInspect(
                Id: image.imageID,
                RepoTags: nil,
                Architecture: "arm64",
                Os: "linux",
                Size: nil,
                VirtualSize: nil,
                Author: nil,
                Config: nil
            )
        )
        let viewModel = DockerManagerViewModel(service: service)
        await viewModel.refreshImages()
        await viewModel.selectImage(image)
        #expect(viewModel.selectedImage != nil)

        await viewModel.deleteImage(image)

        #expect(viewModel.images.isEmpty)
        #expect(viewModel.filteredImages.isEmpty)
        #expect(viewModel.selectedImage == nil)
        #expect(viewModel.selectedImageDetail == nil)
        let removed = await service.removedImages
        #expect(removed.count == 1)
        #expect(removed.first?.id == image.imageID)
    }

    @Test("删除失败时记录错误信息并保留列表")
    func deleteReportsError() async {
        let image = Self.image(id: "sha256:a", repository: "alpha")
        let service = StubDockerService()
        await service.setImages([image])
        await service.setRemoveError(DockerError.commandFailed("nope"))
        let viewModel = DockerManagerViewModel(service: service)
        await viewModel.refreshImages()

        await viewModel.deleteImage(image)

        #expect(viewModel.images.count == 1)
        #expect(viewModel.errorMessage?.contains("nope") == true)
    }

    @Test("搜索按仓库、标签与 ID 过滤")
    func searchFiltersImages() async {
        let service = StubDockerService()
        await service.setImages([
            Self.image(id: "sha256:aaa", repository: "alpha", tag: "latest"),
            Self.image(id: "sha256:bbb", repository: "beta", tag: "v2"),
        ])
        let viewModel = DockerManagerViewModel(service: service)

        viewModel.searchText = "beta"
        await viewModel.refreshImages()

        #expect(viewModel.filteredImages.map(\.repository) == ["beta"])
    }

    @Test("按名称排序")
    func sortsByName() async {
        let service = StubDockerService()
        await service.setImages([
            Self.image(id: "sha256:a", repository: "beta"),
            Self.image(id: "sha256:b", repository: "alpha"),
        ])
        let viewModel = DockerManagerViewModel(service: service)
        await viewModel.refreshImages()

        // 排序由 $sortOption 与 $sortDescending 的 combineLatest 驱动，
        // 任何一个发生变化都会触发重新排序。
        viewModel.sortDescending = false
        viewModel.sortOption = .name
        #expect(viewModel.filteredImages.map(\.repository) == ["alpha", "beta"])

        viewModel.sortDescending = true
        #expect(viewModel.filteredImages.map(\.repository) == ["beta", "alpha"])
    }

    @Test("切换排序项立即按新选项重新排序")
    func sortOptionChangeAppliesToNewOption() async {
        let service = StubDockerService()
        await service.setImages([
            Self.image(id: "sha256:a", repository: "gamma", size: "1 MB", createdAt: "2025-01-01"),
            Self.image(id: "sha256:b", repository: "alpha", size: "3 MB", createdAt: "2026-01-01"),
            Self.image(id: "sha256:c", repository: "beta", size: "2 MB", createdAt: "2024-01-01"),
        ])
        let viewModel = DockerManagerViewModel(service: service)
        await viewModel.refreshImages()

        // 默认：按创建时间倒序
        #expect(viewModel.filteredImages.map(\.repository) == ["alpha", "gamma", "beta"])

        // 改为按名称升序
        viewModel.sortDescending = false
        viewModel.sortOption = .name
        #expect(viewModel.filteredImages.map(\.repository) == ["alpha", "beta", "gamma"])

        // 再改为按体积升序
        viewModel.sortOption = .size
        #expect(viewModel.filteredImages.map(\.repository) == ["gamma", "beta", "alpha"])

        // 只翻转方向，仍沿用体积排序
        viewModel.sortDescending = true
        #expect(viewModel.filteredImages.map(\.repository) == ["alpha", "beta", "gamma"])
    }

    @Test("按体积排序")
    func sortsBySize() async {
        let service = StubDockerService()
        await service.setImages([
            Self.image(id: "sha256:a", repository: "small", size: "1 MB"),
            Self.image(id: "sha256:b", repository: "big", size: "2 MB"),
        ])
        let viewModel = DockerManagerViewModel(service: service)
        await viewModel.refreshImages()

        viewModel.sortDescending = false
        viewModel.sortOption = .size

        #expect(viewModel.filteredImages.map(\.repository) == ["small", "big"])
    }

    @Test("按创建时间排序")
    func sortsByCreated() async {
        let service = StubDockerService()
        await service.setImages([
            Self.image(id: "sha256:a", repository: "older", createdAt: "2025-01-01"),
            Self.image(id: "sha256:b", repository: "newer", createdAt: "2026-01-01"),
        ])
        let viewModel = DockerManagerViewModel(service: service)
        await viewModel.refreshImages()

        viewModel.sortDescending = false
        viewModel.sortOption = .created

        #expect(viewModel.filteredImages.map(\.repository) == ["older", "newer"])
    }

    @Test("扫描成功时写入扫描结果")
    func scanStoresResult() async {
        let image = Self.image(id: "sha256:a", repository: "alpha")
        let service = StubDockerService()
        let viewModel = DockerManagerViewModel(service: service)

        await viewModel.scanImage(image)

        #expect(viewModel.scanResult == "scan output")
        #expect(viewModel.isLoading == false)
    }

    @Test("扫描失败时写入失败原因")
    func scanReportsFailure() async {
        let image = Self.image(id: "sha256:a", repository: "alpha")
        let service = StubDockerService()
        await service.setScanError(DockerError.commandFailed("trivy missing"))
        let viewModel = DockerManagerViewModel(service: service)

        await viewModel.scanImage(image)

        #expect(viewModel.scanResult?.contains("Scan failed") == true)
    }

    @Test("导出失败时记录错误信息")
    func exportReportsFailure() async {
        let image = Self.image(id: "sha256:a", repository: "alpha")
        let service = StubDockerService()
        await service.setExportError(DockerError.commandFailed("disk"))
        let viewModel = DockerManagerViewModel(service: service)

        await viewModel.exportImage(image, to: URL(fileURLWithPath: "/tmp/out.tar"))

        #expect(viewModel.errorMessage?.contains("Export failed") == true)
        #expect(viewModel.isLoading == false)
    }

    @Test("加载失败时记录错误信息")
    func loadReportsFailure() async {
        let service = StubDockerService()
        await service.setLoadError(DockerError.commandFailed("bad tar"))
        let viewModel = DockerManagerViewModel(service: service)

        await viewModel.loadImage(from: URL(fileURLWithPath: "/tmp/in.tar"))

        #expect(viewModel.errorMessage?.contains("Load failed") == true)
    }

    @Test("标签失败时返回 false 并记录错误信息")
    func tagReportsFailure() async {
        let image = Self.image(id: "sha256:a", repository: "alpha")
        let service = StubDockerService()
        await service.setTagError(DockerError.commandFailed("denied"))
        let viewModel = DockerManagerViewModel(service: service)

        let result = await viewModel.tagImage(image, newTag: "repo/name:v1")

        #expect(result == false)
        #expect(viewModel.errorMessage?.contains("Tag failed") == true)
    }

    @Test("拉取成功后刷新列表")
    func pullRefreshesImages() async {
        let service = StubDockerService()
        let viewModel = DockerManagerViewModel(service: service)

        let result = await viewModel.pullImage("ubuntu:22.04")

        #expect(result)
        let pulled = await service.pulledImages
        #expect(pulled == ["ubuntu:22.04"])
    }

    @Test("文件面板取消错误被忽略")
    func ignoresUserCancelledError() {
        let viewModel = DockerManagerViewModel(service: StubDockerService())
        let cancelled = NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: nil
        )

        viewModel.reportFilePanelError("Export", error: cancelled)

        #expect(viewModel.errorMessage == nil)
    }

    @Test("其它文件面板错误被记录")
    func reportsOtherFilePanelError() {
        let viewModel = DockerManagerViewModel(service: StubDockerService())
        let failure = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteUnknownError,
            userInfo: [NSLocalizedDescriptionKey: "disk full"]
        )

        viewModel.reportFilePanelError("Export", error: failure)

        #expect(viewModel.errorMessage?.contains("disk full") == true)
    }

    private static func image(
        id: String,
        repository: String,
        tag: String = "latest",
        size: String = "1 MB",
        createdAt: String = "2026-01-01 00:00:00 +0000 UTC"
    ) -> DockerImage {
        DockerImage(
            imageID: id,
            repository: repository,
            tag: tag,
            createdAt: createdAt,
            createdSince: "1 day ago",
            size: size,
            virtualSize: size,
            digest: ""
        )
    }
}
