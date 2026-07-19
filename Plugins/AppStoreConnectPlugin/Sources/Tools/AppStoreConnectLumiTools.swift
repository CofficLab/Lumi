import Foundation
import LumiKernel

private enum AppStoreConnectToolSupport {
    static func makeClient() -> (client: ConnectClient?, errorMessage: String?) {
        let credentialStore = CredentialStore.shared
        let credentials = credentialStore.load()
        guard credentials.isComplete else {
            return (nil, "App Store Connect credentials are incomplete. Configure issuer ID, key ID, and private key in the App Store plugin settings first.")
        }
        return (ConnectClient(credentialsProvider: { credentialStore.load() }), nil)
    }

    static func parseInt(_ value: LumiJSONValue?) -> Int? {
        if case let .int(number)? = value {
            return number
        }
        if case let .string(raw)? = value {
            return Int(raw)
        }
        return nil
    }

    static func parseBool(_ value: LumiJSONValue?) -> Bool? {
        if case let .bool(flag)? = value {
            return flag
        }
        if case let .string(raw)? = value {
            switch raw.lowercased() {
            case "true", "1", "yes", "y": return true
            case "false", "0", "no", "n": return false
            default: return nil
            }
        }
        return nil
    }
}

struct ListAppStoreConnectAppsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-apps",
        displayName: AppStoreConnectLocalization.string("List App Store apps"),
        description: AppStoreConnectLocalization.string("List apps from App Store Connect using the configured API key.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "search": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Optional case-insensitive search query to filter apps by name."))
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string(AppStoreConnectLocalization.string("Maximum number of apps to return (default 20, max 100)."))
                ])
            ])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let search = arguments["search"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawLimit = AppStoreConnectToolSupport.parseInt(arguments["limit"])
        let limit = min(max(rawLimit ?? 20, 1), 100)

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let apps = try await client.listApps(search: search, limit: limit)
            if apps.isEmpty {
                return "No apps were found for the current App Store Connect account."
            }

            let header = "App Store Connect apps (showing \(apps.count)):"
            let lines = apps.map { app in
                let platform = app.platform
                return "- \(app.name) (\(app.bundleID)) [\(platform)] id=\(app.id)"
            }
            return ([header] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list apps: \(error.localizedDescription)"
        }
    }
}

struct ListAppStoreConnectVersionsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-versions",
        displayName: AppStoreConnectLocalization.string("List App Store versions"),
        description: AppStoreConnectLocalization.string("List App Store Connect versions for a given app ID.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect app identifier (see id field from list-apps)."))
                ])
            ]),
            "required": .array([.string("appID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let appID = arguments["appID"]?.stringValue, !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty appID. Pass a valid App Store Connect app identifier."
        }

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let versions = try await client.listVersions(appID: appID)
            if versions.isEmpty {
                return "No App Store versions were found for this app."
            }

            let header = "App Store versions for app id=\(appID):"
            let lines = versions.map { version in
                let created = version.createdDate?.description ?? "unknown date"
                return "- \(version.versionString) [\(version.platform)] state=\(version.appStoreState) created=\(created)"
            }
            return ([header] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list versions: \(error.localizedDescription)"
        }
    }
}

struct CreateAppStoreConnectVersionTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.create-version",
        displayName: AppStoreConnectLocalization.string("New Version"),
        description: AppStoreConnectLocalization.string("Create a new App Store version for the selected app.")
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "appID": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("The App Store Connect app identifier (see id field from list-apps)."))
                ]),
                "versionString": .object([
                    "type": .string("string"),
                    "description": .string(AppStoreConnectLocalization.string("Version Number"))
                ]),
                "platform": .object([
                    "type": .string("string"),
                    "description": .string("Platform: IOS, MAC_OS, TV_OS, or VISION_OS.")
                ]),
                "releaseType": .object([
                    "type": .string("string"),
                    "description": .string("Optional release type: AFTER_APPROVAL (default) or MANUAL.")
                ])
            ]),
            "required": .array([.string("appID"), .string("versionString"), .string("platform")])
        ])
    }

    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let appID = arguments["appID"]?.stringValue, !appID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty appID."
        }
        guard let versionString = arguments["versionString"]?.stringValue,
              !versionString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty versionString."
        }
        guard let platform = arguments["platform"]?.stringValue,
              !platform.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Missing or empty platform."
        }

        let releaseType = arguments["releaseType"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedReleaseType = (releaseType?.isEmpty == false) ? releaseType! : "AFTER_APPROVAL"

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        do {
            let existingVersions = try await client.listVersions(appID: appID)
            let validated = try AppStoreVersion.validateCreate(
                versionString: versionString,
                platform: platform,
                versions: existingVersions
            )
            let created = try await client.createVersion(
                appID: appID,
                versionString: validated.versionString,
                platform: validated.platform,
                releaseType: resolvedReleaseType
            )
            return "App Store version created: id=\(created.id) version=\(created.versionString) platform=\(created.platform) state=\(created.appStoreState)"
        } catch {
            return "Failed to create version: \(error.localizedDescription)"
        }
    }
}

struct ListAppStoreConnectLocalizationsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-localizations",
        displayName: "List App Store localizations",
        description: "List localizations for an App Store version."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "versionID": .object([
                    "type": .string("string"),
                    "description": .string("The App Store Connect appStoreVersion id.")
                ])
            ]),
            "required": .array([.string("versionID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let versionID = arguments["versionID"]?.stringValue, !versionID.isEmpty else {
            return "Missing or empty versionID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let localizations = try await client.listLocalizations(versionID: versionID)
            guard !localizations.isEmpty else { return "No localizations found for version id=\(versionID)." }
            let lines = localizations.map {
                "- \($0.locale) id=\($0.id) whatsNew=\($0.whatsNew.isEmpty ? "empty" : "present")"
            }
            return (["Localizations for version id=\(versionID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list localizations: \(error.localizedDescription)"
        }
    }
}

struct ListAppStoreConnectScreenshotSetsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-screenshot-sets",
        displayName: "List screenshot sets",
        description: "List screenshot sets for a localization."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object([
                    "type": .string("string"),
                    "description": .string("The appStoreVersionLocalization id.")
                ])
            ]),
            "required": .array([.string("localizationID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let payload = try await client.loadScreenshotSets(localizationID: localizationID)
            guard !payload.sets.isEmpty else { return "No screenshot sets found for localization id=\(localizationID)." }
            let lines = payload.sets.map { set in
                let count = payload.screenshotsBySetID[set.id]?.count ?? set.screenshotIDs.count
                return "- \(set.screenshotDisplayType) setID=\(set.id) screenshots=\(count)"
            }
            return (["Screenshot sets for localization id=\(localizationID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list screenshot sets: \(error.localizedDescription)"
        }
    }
}

struct ListAppStoreConnectScreenshotsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-screenshots",
        displayName: "List screenshots",
        description: "List screenshots for a screenshot set."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "screenshotSetID": .object([
                    "type": .string("string"),
                    "description": .string("The appScreenshotSet id.")
                ])
            ]),
            "required": .array([.string("screenshotSetID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let screenshotSetID = arguments["screenshotSetID"]?.stringValue, !screenshotSetID.isEmpty else {
            return "Missing or empty screenshotSetID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let screenshots = try await client.listScreenshots(screenshotSetID: screenshotSetID)
            guard !screenshots.isEmpty else { return "No screenshots found for screenshot set id=\(screenshotSetID)." }
            let lines = screenshots.map { shot in
                let size = shot.fileSize.map(String.init) ?? "unknown"
                return "- \(shot.fileName.isEmpty ? "(unnamed)" : shot.fileName) id=\(shot.id) bytes=\(size)"
            }
            return (["Screenshots for set id=\(screenshotSetID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list screenshots: \(error.localizedDescription)"
        }
    }
}

struct ListAppStoreConnectCiProductsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-ci-products",
        displayName: "List Xcode Cloud products",
        description: "List Xcode Cloud CI products from App Store Connect."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let products = try await client.listCiProducts()
            guard !products.isEmpty else { return "No Xcode Cloud products found." }
            let lines = products.map { product in
                "- \(product.name) id=\(product.id) bundleID=\(product.bundleID) type=\(product.productType)"
            }
            return (["Xcode Cloud products:"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list CI products: \(error.localizedDescription)"
        }
    }
}

struct ListAppStoreConnectCiWorkflowsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-ci-workflows",
        displayName: "List Xcode Cloud workflows",
        description: "List workflows under a Xcode Cloud product."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "productID": .object([
                    "type": .string("string"),
                    "description": .string("The ciProduct id.")
                ])
            ]),
            "required": .array([.string("productID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let productID = arguments["productID"]?.stringValue, !productID.isEmpty else {
            return "Missing or empty productID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let workflows = try await client.listCiWorkflows(productID: productID)
            guard !workflows.isEmpty else { return "No workflows found for product id=\(productID)." }
            let lines = workflows.map { wf in
                "- \(wf.name) id=\(wf.id) enabled=\(wf.isEnabled) platform=\(wf.platformType)"
            }
            return (["Xcode Cloud workflows for product id=\(productID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list CI workflows: \(error.localizedDescription)"
        }
    }
}

struct ReadAppStoreConnectCiWorkflowTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.read-ci-workflow",
        displayName: "Read Xcode Cloud workflow",
        description: "Read a single workflow detail from Xcode Cloud."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object([
                    "type": .string("string"),
                    "description": .string("The ciWorkflow id.")
                ])
            ]),
            "required": .array([.string("workflowID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let wf = try await client.readCiWorkflow(id: workflowID)
            return """
            Workflow detail:
            - id=\(wf.id)
            - name=\(wf.name)
            - enabled=\(wf.isEnabled)
            - clean=\(wf.clean)
            - platform=\(wf.platformType)
            - containerFilePath=\(wf.containerFilePath)
            - description=\(wf.description.isEmpty ? "(empty)" : wf.description)
            """
        } catch {
            return "Failed to read CI workflow: \(error.localizedDescription)"
        }
    }
}

struct ListAppStoreConnectCiBuildRunsTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.list-ci-build-runs",
        displayName: "List Xcode Cloud build runs",
        description: "List build runs for a Xcode Cloud workflow."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object([
                    "type": .string("string"),
                    "description": .string("The ciWorkflow id.")
                ]),
                "limit": .object([
                    "type": .string("integer"),
                    "description": .string("Maximum number of build runs to return (default 20, max 200).")
                ])
            ]),
            "required": .array([.string("workflowID")])
        ])
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        let parsedLimit = AppStoreConnectToolSupport.parseInt(arguments["limit"]) ?? 20
        let limit = min(max(parsedLimit, 1), 200)

        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let runs = try await client.listCiBuildRuns(workflowID: workflowID, limit: limit)
            guard !runs.isEmpty else { return "No build runs found for workflow id=\(workflowID)." }
            let lines = runs.map { run in
                let number = run.number.map(String.init) ?? "n/a"
                let status = run.completionStatus ?? "in-progress"
                return "- run=\(number) id=\(run.id) progress=\(run.executionProgress) status=\(status)"
            }
            return (["Build runs for workflow id=\(workflowID):"] + lines).joined(separator: "\n")
        } catch {
            return "Failed to list CI build runs: \(error.localizedDescription)"
        }
    }
}

struct UpdateAppStoreConnectLocalizationTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.update-localization",
        displayName: "Update localization metadata",
        description: "Update editable fields of an App Store version localization."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object(["type": .string("string"), "description": .string("The appStoreVersionLocalization id.")]),
                "promotionalText": .object(["type": .string("string")]),
                "description": .object(["type": .string("string")]),
                "keywords": .object(["type": .string("string")]),
                "whatsNew": .object(["type": .string("string")]),
                "supportURL": .object(["type": .string("string")]),
                "marketingURL": .object(["type": .string("string")])
            ]),
            "required": .array([.string("localizationID")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }

        let payload = AppStoreVersionLocalization(
            id: localizationID,
            locale: "en-US",
            promotionalText: arguments["promotionalText"]?.stringValue ?? "",
            description: arguments["description"]?.stringValue ?? "",
            keywords: arguments["keywords"]?.stringValue ?? "",
            whatsNew: arguments["whatsNew"]?.stringValue ?? "",
            supportURL: arguments["supportURL"]?.stringValue ?? "",
            marketingURL: arguments["marketingURL"]?.stringValue ?? ""
        )

        do {
            let updated = try await client.updateLocalization(payload)
            return "Localization updated: id=\(updated.id) locale=\(updated.locale)"
        } catch {
            return "Failed to update localization: \(error.localizedDescription)"
        }
    }
}

struct CreateAppStoreConnectScreenshotSetTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.create-screenshot-set",
        displayName: "Create screenshot set",
        description: "Create a screenshot set for a localization and display type."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "localizationID": .object(["type": .string("string"), "description": .string("The appStoreVersionLocalization id.")]),
                "displayType": .object(["type": .string("string"), "description": .string("Screenshot display type, e.g. APP_DESKTOP, APP_IPHONE_67.")])
            ]),
            "required": .array([.string("localizationID"), .string("displayType")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let localizationID = arguments["localizationID"]?.stringValue, !localizationID.isEmpty else {
            return "Missing or empty localizationID."
        }
        guard let displayType = arguments["displayType"]?.stringValue, !displayType.isEmpty else {
            return "Missing or empty displayType."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let set = try await client.createScreenshotSet(localizationID: localizationID, displayType: displayType)
            return "Screenshot set created: id=\(set.id) displayType=\(set.screenshotDisplayType)"
        } catch {
            return "Failed to create screenshot set: \(error.localizedDescription)"
        }
    }
}

struct StartAppStoreConnectCiBuildRunTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.start-ci-build-run",
        displayName: "Start Xcode Cloud build run",
        description: "Trigger a new build run for a workflow."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object(["type": .string("string"), "description": .string("The ciWorkflow id.")]),
                "branch": .object(["type": .string("string"), "description": .string("Optional source branch or tag.")])
            ]),
            "required": .array([.string("workflowID")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        let branch = arguments["branch"]?.stringValue ?? ""
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let run = try await client.startCiBuildRun(workflowID: workflowID, branch: branch)
            let number = run.number.map(String.init) ?? "n/a"
            return "Build run started: id=\(run.id) number=\(number) progress=\(run.executionProgress)"
        } catch {
            return "Failed to start CI build run: \(error.localizedDescription)"
        }
    }
}

struct SetAppStoreConnectCiWorkflowEnabledTool: LumiAgentTool {
    static let info = LumiAgentToolInfo(
        id: "app-store-connect.set-ci-workflow-enabled",
        displayName: "Enable or disable workflow",
        description: "Update a Xcode Cloud workflow enabled state."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "workflowID": .object(["type": .string("string"), "description": .string("The ciWorkflow id.")]),
                "isEnabled": .object(["type": .string("boolean"), "description": .string("true to enable, false to disable.")])
            ]),
            "required": .array([.string("workflowID"), .string("isEnabled")])
        ])
    }

    func riskLevel(arguments: [String : LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .high
    }

    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let workflowID = arguments["workflowID"]?.stringValue, !workflowID.isEmpty else {
            return "Missing or empty workflowID."
        }
        guard let isEnabled = AppStoreConnectToolSupport.parseBool(arguments["isEnabled"]) else {
            return "Missing or invalid isEnabled. Use true or false."
        }
        let (client, errorMessage) = AppStoreConnectToolSupport.makeClient()
        guard let client else { return errorMessage ?? "Failed to initialize App Store Connect client." }
        do {
            let workflow = try await client.updateCiWorkflowEnabled(id: workflowID, isEnabled: isEnabled)
            return "Workflow updated: id=\(workflow.id) enabled=\(workflow.isEnabled)"
        } catch {
            return "Failed to update workflow: \(error.localizedDescription)"
        }
    }
}

