import Foundation

enum TestRunnerDetector {
    static func preferredScript(package: JSPackageInfo?) -> String? {
        guard let package else { return nil }
        if package.scripts["test"] != nil { return "test" }
        return package.testScripts.first
    }

    static func framework(package: JSPackageInfo?) -> JSPackageInfo.TestFramework? {
        package?.inferredTestFramework
    }

    static func defaultArguments(for framework: JSPackageInfo.TestFramework?) -> [String] {
        switch framework {
        case .vitest:
            return ["--", "--run", "--reporter=verbose"]
        case .jest:
            return ["--", "--runInBand"]
        case .playwright:
            return ["--", "--reporter=line"]
        case .mocha, .none:
            return []
        }
    }
}
