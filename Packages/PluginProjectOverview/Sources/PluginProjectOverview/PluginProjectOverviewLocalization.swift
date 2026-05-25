import Foundation

enum PluginProjectOverviewLocalization {
    static let table = "ProjectOverview"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        NSLocalizedString(key, tableName: table, bundle: bundle, value: key, comment: "")
    }
}
