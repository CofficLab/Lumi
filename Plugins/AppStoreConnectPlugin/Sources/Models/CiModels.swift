import Foundation

struct CiProduct: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    let productType: String
    let bundleID: String
    let createdDate: Date?
    let appID: String?
    let primaryAppID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }

    enum AttributeKeys: String, CodingKey {
        case name
        case productType
        case bundleID = "bundleId"
        case createdDate
    }

    enum RelationshipKeys: String, CodingKey {
        case app
        case primaryApp
    }

    init(
        id: String,
        name: String,
        productType: String,
        bundleID: String,
        createdDate: Date? = nil,
        appID: String? = nil,
        primaryAppID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.productType = productType
        self.bundleID = bundleID
        self.createdDate = createdDate
        self.appID = appID
        self.primaryAppID = primaryAppID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        name = try attributes.decodeIfPresent(String.self, forKey: .name) ?? AppStoreConnectLocalization.string("Untitled")
        productType = try attributes.decodeIfPresent(String.self, forKey: .productType) ?? "-"
        bundleID = try attributes.decodeIfPresent(String.self, forKey: .bundleID) ?? "-"
        createdDate = try attributes.decodeIfPresent(Date.self, forKey: .createdDate)

        if let relationships = try? container.nestedContainer(keyedBy: RelationshipKeys.self, forKey: .relationships) {
            appID = (try? relationships.decode(AppStoreConnectRelationship.self, forKey: .app))?.data?.id
            primaryAppID = (try? relationships.decode(AppStoreConnectRelationship.self, forKey: .primaryApp))?.data?.id
        } else {
            appID = nil
            primaryAppID = nil
        }
    }
}

struct CiWorkflow: Identifiable, Equatable, Decodable {
    let id: String
    let name: String
    let description: String
    let isEnabled: Bool
    let clean: Bool
    let containerFilePath: String
    let platformType: String
    let createdDate: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
    }

    enum AttributeKeys: String, CodingKey {
        case name
        case description
        case isEnabled
        case clean
        case containerFilePath
        case platformType
        case createdDate
    }

    init(
        id: String,
        name: String,
        description: String = "",
        isEnabled: Bool = false,
        clean: Bool = false,
        containerFilePath: String = "",
        platformType: String = "-",
        createdDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.isEnabled = isEnabled
        self.clean = clean
        self.containerFilePath = containerFilePath
        self.platformType = platformType
        self.createdDate = createdDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        name = try attributes.decodeIfPresent(String.self, forKey: .name) ?? AppStoreConnectLocalization.string("Untitled")
        description = try attributes.decodeIfPresent(String.self, forKey: .description) ?? ""
        isEnabled = try attributes.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        clean = try attributes.decodeIfPresent(Bool.self, forKey: .clean) ?? false
        containerFilePath = try attributes.decodeIfPresent(String.self, forKey: .containerFilePath) ?? ""
        platformType = try attributes.decodeIfPresent(String.self, forKey: .platformType) ?? "-"
        createdDate = try attributes.decodeIfPresent(Date.self, forKey: .createdDate)
    }
}

struct CiBuildRun: Identifiable, Equatable, Decodable {
    let id: String
    let number: Int?
    let createdDate: Date?
    let startedDate: Date?
    let finishedDate: Date?
    let isPullRequestBuild: Bool
    let executionProgress: String
    let completionStatus: String?
    let workflowID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case attributes
        case relationships
    }

    enum AttributeKeys: String, CodingKey {
        case number
        case createdDate
        case startedDate
        case finishedDate
        case isPullRequestBuild
        case executionProgress
        case completionStatus
    }

    enum RelationshipKeys: String, CodingKey {
        case workflow
    }

    init(
        id: String,
        number: Int? = nil,
        createdDate: Date? = nil,
        startedDate: Date? = nil,
        finishedDate: Date? = nil,
        isPullRequestBuild: Bool = false,
        executionProgress: String = "-",
        completionStatus: String? = nil,
        workflowID: String? = nil
    ) {
        self.id = id
        self.number = number
        self.createdDate = createdDate
        self.startedDate = startedDate
        self.finishedDate = finishedDate
        self.isPullRequestBuild = isPullRequestBuild
        self.executionProgress = executionProgress
        self.completionStatus = completionStatus
        self.workflowID = workflowID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        let attributes = try container.nestedContainer(keyedBy: AttributeKeys.self, forKey: .attributes)
        number = try attributes.decodeIfPresent(Int.self, forKey: .number)
        createdDate = try attributes.decodeIfPresent(Date.self, forKey: .createdDate)
        startedDate = try attributes.decodeIfPresent(Date.self, forKey: .startedDate)
        finishedDate = try attributes.decodeIfPresent(Date.self, forKey: .finishedDate)
        isPullRequestBuild = try attributes.decodeIfPresent(Bool.self, forKey: .isPullRequestBuild) ?? false
        executionProgress = try attributes.decodeIfPresent(String.self, forKey: .executionProgress) ?? "-"
        completionStatus = try attributes.decodeIfPresent(String.self, forKey: .completionStatus)

        if let relationships = try? container.nestedContainer(keyedBy: RelationshipKeys.self, forKey: .relationships),
           let workflow = try? relationships.decode(AppStoreConnectRelationship.self, forKey: .workflow) {
            workflowID = workflow.data?.id
        } else {
            workflowID = nil
        }
    }
}

struct CiWorkflowExport: Equatable, Encodable {
    let id: String
    let name: String
    let description: String
    let isEnabled: Bool
    let clean: Bool
    let containerFilePath: String
    let platformType: String

    init(workflow: CiWorkflow) {
        self.id = workflow.id
        self.name = workflow.name
        self.description = workflow.description
        self.isEnabled = workflow.isEnabled
        self.clean = workflow.clean
        self.containerFilePath = workflow.containerFilePath
        self.platformType = workflow.platformType
    }
}
