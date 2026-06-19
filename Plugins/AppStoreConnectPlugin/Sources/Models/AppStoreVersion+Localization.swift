import Foundation

extension AppStoreVersion {
    var localizedAppStoreStateLabel: String {
        switch appStoreState.uppercased() {
        case "PENDING_DEVELOPER_RELEASE":
            return AppStoreConnectLocalization.string("Pending Developer Release")
        case "READY_FOR_SALE":
            return AppStoreConnectLocalization.string("Ready for Sale")
        case "PREPARE_FOR_SUBMISSION":
            return AppStoreConnectLocalization.string("Prepare for Submission")
        case "WAITING_FOR_REVIEW":
            return AppStoreConnectLocalization.string("Waiting for Review")
        case "IN_REVIEW":
            return AppStoreConnectLocalization.string("In Review")
        case "WAITING_FOR_REVIEWER_ACTION":
            return AppStoreConnectLocalization.string("Waiting for Reviewer Action")
        case "WAITING_FOR_EXPORT_COMPLIANCE":
            return AppStoreConnectLocalization.string("Waiting for Export Compliance")
        case "PENDING_APPLE_RELEASE":
            return AppStoreConnectLocalization.string("Pending Apple Release")
        case "PROCESSING_FOR_DISTRIBUTION":
            return AppStoreConnectLocalization.string("Processing for Distribution")
        case "REJECTED", "METADATA_REJECTED":
            return AppStoreConnectLocalization.string("Rejected")
        case "DEVELOPER_REJECTED":
            return AppStoreConnectLocalization.string("Developer Rejected")
        case "REPLACED_WITH_NEW_VERSION":
            return AppStoreConnectLocalization.string("Replaced")
        case "REMOVED_FROM_SALE", "DEVELOPER_REMOVED_FROM_SALE":
            return AppStoreConnectLocalization.string("Removed from Sale")
        default:
            return appStoreState
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}
