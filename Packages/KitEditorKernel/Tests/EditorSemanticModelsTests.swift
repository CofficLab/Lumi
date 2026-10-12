import Foundation
import Testing
@testable import EditorKernel

@Suite("EditorSemanticModels Tests")
struct EditorSemanticModelsTests {

    @Test
    func workspaceFolderInitialization() {
        let folder = EditorWorkspaceFolder(uri: "file:///test", name: "TestFolder")
        #expect(folder.uri == "file:///test")
        #expect(folder.name == "TestFolder")
    }

    @Test
    func workspaceFolderEquality() {
        let folder1 = EditorWorkspaceFolder(uri: "file:///test", name: "Test")
        let folder2 = EditorWorkspaceFolder(uri: "file:///test", name: "Test")
        let folder3 = EditorWorkspaceFolder(uri: "file:///other", name: "Test")

        #expect(folder1 == folder2)
        #expect(folder1 != folder3)
    }

    @Test
    func semanticPreflightStrengthCases() {
        #expect(EditorSemanticPreflightStrength.soft != EditorSemanticPreflightStrength.hard)
    }

    @Test
    func semanticAvailabilitySeverityRawValues() {
        #expect(EditorSemanticAvailabilitySeverity.info.rawValue == "info")
        #expect(EditorSemanticAvailabilitySeverity.warning.rawValue == "warning")
        #expect(EditorSemanticAvailabilitySeverity.error.rawValue == "error")
    }

    @Test
    func semanticAvailabilityReasonInitialization() {
        let reason = EditorSemanticAvailabilityReason(
            id: "test-id",
            severity: .warning,
            title: "Test Title",
            message: "Test Message",
            suggestion: "Test Suggestion"
        )

        #expect(reason.id == "test-id")
        #expect(reason.severity == .warning)
        #expect(reason.title == "Test Title")
        #expect(reason.message == "Test Message")
        #expect(reason.suggestion == "Test Suggestion")
    }

    @Test
    func semanticAvailabilityReasonWithoutSuggestion() {
        let reason = EditorSemanticAvailabilityReason(
            id: "test-id",
            severity: .error,
            title: "Test Title",
            message: "Test Message"
        )

        #expect(reason.suggestion == nil)
    }

    @Test
    func semanticAvailabilityReasonEquality() {
        let reason1 = EditorSemanticAvailabilityReason(id: "1", severity: .info, title: "T", message: "M")
        let reason2 = EditorSemanticAvailabilityReason(id: "1", severity: .info, title: "T", message: "M")
        let reason3 = EditorSemanticAvailabilityReason(id: "2", severity: .info, title: "T", message: "M")

        #expect(reason1 == reason2)
        #expect(reason1 != reason3)
    }

    @Test
    func semanticAvailabilityReportInitialization() {
        let reasons = [
            EditorSemanticAvailabilityReason(id: "1", severity: .info, title: "T1", message: "M1"),
            EditorSemanticAvailabilityReason(id: "2", severity: .warning, title: "T2", message: "M2")
        ]
        let report = EditorSemanticAvailabilityReport(reasons: reasons)

        #expect(report.reasons.count == 2)
    }

    @Test
    func semanticAvailabilityReportEmpty() {
        let report = EditorSemanticAvailabilityReport.empty
        #expect(report.reasons.isEmpty)
    }

    @Test
    func semanticAvailabilityReportEquality() {
        let reasons = [EditorSemanticAvailabilityReason(id: "1", severity: .info, title: "T", message: "M")]
        let report1 = EditorSemanticAvailabilityReport(reasons: reasons)
        let report2 = EditorSemanticAvailabilityReport(reasons: reasons)

        #expect(report1 == report2)
    }

    @Test
    func languageFeatureErrorInitialization() {
        let error = EditorLanguageFeatureError(
            domain: "LSP",
            code: "TIMEOUT",
            message: "Request timed out",
            suggestion: "Try again"
        )

        #expect(error.domain == "LSP")
        #expect(error.code == "TIMEOUT")
        #expect(error.message == "Request timed out")
        #expect(error.suggestion == "Try again")
        #expect(error.errorDescription == "Request timed out")
        #expect(error.recoverySuggestion == "Try again")
    }

    @Test
    func languageFeatureErrorWithoutSuggestion() {
        let error = EditorLanguageFeatureError(
            domain: "LSP",
            code: "ERROR",
            message: "Generic error"
        )

        #expect(error.suggestion == nil)
        #expect(error.recoverySuggestion == nil)
    }

    @Test
    func languageFeatureErrorEquality() {
        let error1 = EditorLanguageFeatureError(domain: "LSP", code: "E1", message: "M1")
        let error2 = EditorLanguageFeatureError(domain: "LSP", code: "E1", message: "M1")
        let error3 = EditorLanguageFeatureError(domain: "LSP", code: "E2", message: "M1")

        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test
    func languageFeatureErrorLocalizedError() {
        let error = EditorLanguageFeatureError(domain: "Test", code: "TestCode", message: "Test message")
        #expect(error.errorDescription == "Test message")
    }

    @Test
    func semanticProblemInitializationDirect() {
        let problem = EditorSemanticProblem(
            id: "problem-1",
            severity: .error,
            title: "Problem Title",
            message: "Problem Message"
        )

        #expect(problem.id == "problem-1")
        #expect(problem.severity == .error)
        #expect(problem.title == "Problem Title")
        #expect(problem.message == "Problem Message")
    }

    @Test
    func semanticProblemInitializationFromReason() {
        let reason = EditorSemanticAvailabilityReason(
            id: "reason-1",
            severity: .warning,
            title: "Reason Title",
            message: "Reason Message"
        )
        let problem = EditorSemanticProblem(reason: reason)

        #expect(problem.id == "reason-1")
        #expect(problem.severity == .warning)
        #expect(problem.title == "Reason Title")
        #expect(problem.message == "Reason Message")
    }

    @Test
    func semanticProblemEquality() {
        let problem1 = EditorSemanticProblem(id: "1", severity: .info, title: "T", message: "M")
        let problem2 = EditorSemanticProblem(id: "1", severity: .info, title: "T", message: "M")
        let problem3 = EditorSemanticProblem(id: "2", severity: .info, title: "T", message: "M")

        #expect(problem1 == problem2)
        #expect(problem1 != problem3)
    }

    @Test
    func semanticProblemFromReasonEquality() {
        let reason1 = EditorSemanticAvailabilityReason(id: "1", severity: .info, title: "T", message: "M")
        let reason2 = EditorSemanticAvailabilityReason(id: "1", severity: .info, title: "T", message: "M")
        let reason3 = EditorSemanticAvailabilityReason(id: "2", severity: .info, title: "T", message: "M")

        let problem1 = EditorSemanticProblem(reason: reason1)
        let problem2 = EditorSemanticProblem(reason: reason2)
        let problem3 = EditorSemanticProblem(reason: reason3)

        #expect(problem1 == problem2)
        #expect(problem1 != problem3)
    }

    @Test
    func semanticProblemIdentifiable() {
        let problem = EditorSemanticProblem(id: "unique-id", severity: .error, title: "T", message: "M")
        #expect(problem.id == "unique-id")
    }
}