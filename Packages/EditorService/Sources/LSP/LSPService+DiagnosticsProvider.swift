import Combine
import Foundation
import LanguageServerProtocol

extension LSPService: SuperEditorLSPDiagnosticsProvider {
    public var diagnosticsPublisher: AnyPublisher<[Diagnostic], Never> {
        $currentDiagnostics.eraseToAnyPublisher()
    }
}
