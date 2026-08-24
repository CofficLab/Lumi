import Foundation

extension VM {
    // MARK: - Release Info Loading

    /// 加载版本的发布相关信息：可选 builds、已关联 build、审核提交状态。
    func loadReleaseInfo(forceRefresh: Bool = false) async {
        guard let app = selectedApp, let version = selectedVersion else { return }
        await runBusy(forceRefresh: forceRefresh) {
            async let buildsTask = client.listBuilds(appID: app.id, platform: version.platform)
            async let assignedTask = client.readAssignedBuildID(versionID: version.id)
            async let submissionTask = client.readSubmissionID(versionID: version.id)

            let (fetchedBuilds, assigned, submission) = try await (buildsTask, assignedTask, submissionTask)
            builds = fetchedBuilds
            assignedBuildID = assigned
            submissionID = submission
            if let assigned, fetchedBuilds.contains(where: { $0.id == assigned }) {
                selectedBuildID = assigned
            } else if selectedBuildID == nil || !fetchedBuilds.contains(where: { $0.id == selectedBuildID }) {
                selectedBuildID = fetchedBuilds.first(where: { $0.isAssignable })?.id
            }
            Self.logger.info("\(self.t)loadReleaseInfo builds=\(fetchedBuilds.count) assigned=\(assigned ?? "nil") submission=\(submission ?? "nil")")
        }
    }

    // MARK: - Build Assignment

    /// 将选中的 build 关联到当前版本。
    func assignSelectedBuild() async {
        guard let version = selectedVersion, let buildID = selectedBuildID else { return }
        guard version.canAssignBuild else { return }
        await runBusy(forceRefresh: true) {
            try await client.assignBuild(versionID: version.id, buildID: buildID)
            assignedBuildID = buildID
            Self.logger.info("\(self.t)assignSelectedBuild assigned build=\(buildID) to version=\(version.id)")
        }
    }

    /// 更新构建的出口合规声明（是否使用非豁免加密）。
    func updateSelectedBuildEncryption(usesNonExemptEncryption: Bool) async {
        guard let buildID = selectedBuildID else { return }
        await runBusy(forceRefresh: true) {
            try await client.updateBuildEncryption(buildID: buildID, usesNonExemptEncryption: usesNonExemptEncryption)
            if let index = builds.firstIndex(where: { $0.id == buildID }) {
                let old = builds[index]
                builds[index] = ConnectBuild(
                    id: old.id,
                    version: old.version,
                    uploadedDate: old.uploadedDate,
                    expirationDate: old.expirationDate,
                    expired: old.expired,
                    minOsVersion: old.minOsVersion,
                    processingState: old.processingState,
                    usesNonExemptEncryption: usesNonExemptEncryption,
                    preReleaseVersionString: old.preReleaseVersionString,
                    preReleaseVersionID: old.preReleaseVersionID
                )
            }
        }
    }

    // MARK: - Submission

    /// 将当前版本提交审核。
    func submitForReview() async {
        guard let version = selectedVersion, version.isSubmittable else { return }
        await runBusy(forceRefresh: true) {
            let newSubmissionID = try await client.submitForReview(versionID: version.id)
            submissionID = newSubmissionID
            Self.logger.info("\(self.t)submitForReview submitted version=\(version.id) submission=\(newSubmissionID)")
            try await refreshVersionState()
        }
    }

    /// 撤回当前版本的审核提交。
    func withdrawSubmission() async {
        guard let version = selectedVersion, let submissionID else { return }
        await runBusy(forceRefresh: true) {
            try await client.withdrawSubmission(submissionID: submissionID)
            self.submissionID = nil
            Self.logger.info("\(self.t)withdrawSubmission withdrew submission=\(submissionID)")
            try await refreshVersionState()
        }
    }

    // MARK: - Screenshot Upload

    /// 上传所有状态为 ready 的待传截图到当前截图集，完成后刷新远端列表。
    func uploadPendingScreenshots() async {
        guard !isReadOnlyVersion else { return }
        guard let set = selectedScreenshotSet else {
            errorMessage = AppStoreConnectLocalization.string("Create a screenshot set for the selected display type before uploading.")
            return
        }
        let uploadables = pendingScreenshots.filter {
            if case .ready = $0.status { return true }
            return false
        }
        guard !uploadables.isEmpty else { return }

        isUploadingScreenshots = true
        defer { isUploadingScreenshots = false }

        var failures: [String] = []
        for pending in uploadables {
            markPendingScreenshot(pending, status: .uploading)
            do {
                _ = try await client.uploadScreenshot(setID: set.id, fileURL: pending.url)
                markPendingScreenshot(pending, status: .uploaded)
            } catch {
                Self.logger.error("\(self.t)uploadPendingScreenshots failed for \(pending.fileName): \(error.localizedDescription)")
                markPendingScreenshot(pending, status: .failed(error.localizedDescription))
                failures.append("\(pending.fileName): \(error.localizedDescription)")
            }
        }

        // 移除已上传成功的项，刷新远端截图列表
        pendingScreenshots.removeAll {
            if case .uploaded = $0.status { return true }
            return false
        }
        await runBusy(forceRefresh: true) {
            try await loadScreenshots()
        }
        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
        }
    }

    /// 删除一张远端截图并刷新列表。
    func deleteRemoteScreenshot(_ screenshot: AppScreenshot) async {
        guard !isReadOnlyVersion else { return }
        await runBusy(forceRefresh: true) {
            try await client.deleteScreenshot(id: screenshot.id)
            try await loadScreenshots()
        }
    }

    // MARK: - Private

    private func markPendingScreenshot(_ pending: PendingScreenshot, status: PendingScreenshot.Status) {
        guard let index = pendingScreenshots.firstIndex(where: { $0.id == pending.id }) else { return }
        pendingScreenshots[index].status = status
    }

    private func refreshVersionState() async throws {
        guard let app = selectedApp, let version = selectedVersion else { return }
        versions = try await client.listVersions(appID: app.id)
        client.pruneStaleVersionCache(keepingVersionIDs: Set(versions.map(\.id)))
        if let updated = versions.first(where: { $0.id == version.id }) {
            selectedVersion = updated
        }
    }
}

extension AppStoreVersion {
    /// 是否可以关联/更换 build（仅准备提交阶段）
    var canAssignBuild: Bool {
        appStoreState.uppercased() == "PREPARE_FOR_SUBMISSION"
    }

    /// 是否可以提交审核（准备提交 / 被拒后重新提交等）
    var isSubmittable: Bool {
        switch appStoreState.uppercased() {
        case "PREPARE_FOR_SUBMISSION",
             "DEVELOPER_REJECTED",
             "REJECTED",
             "INVALID_BINARY",
             "METADATA_REJECTED":
            return true
        default:
            return false
        }
    }
}
