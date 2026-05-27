import Foundation

@MainActor
public final class IconDocumentStore: ObservableObject {
    public static let shared = IconDocumentStore()

    @Published public private(set) var documents: [IconDocument] = []
    @Published public var selectedDocumentId: String?
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var lastError: String?

    public init() {}

    public var selectedDocument: IconDocument? {
        guard let selectedDocumentId else { return documents.first }
        return documents.first { $0.id == selectedDocumentId } ?? documents.first
    }

    @discardableResult
    public func createDocument(title: String?, width: Double, height: Double, background: IconPaint) -> IconDocument {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = IconDocument(
            title: trimmedTitle?.isEmpty == false ? trimmedTitle! : "Untitled Icon",
            width: max(1, width),
            height: max(1, height),
            background: background
        )
        documents.insert(document, at: 0)
        selectedDocumentId = document.id
        lastError = nil
        return document
    }

    @discardableResult
    public func updateSelectedDocument(_ update: (inout IconDocument) throws -> Void) throws -> IconDocument {
        guard let selectedDocumentId, let index = documents.firstIndex(where: { $0.id == selectedDocumentId }) else {
            throw IconDocumentStoreError.noSelectedDocument
        }

        try update(&documents[index])
        documents[index].updatedAt = Date()
        lastError = nil
        return documents[index]
    }

    @discardableResult
    public func addLayer(_ layer: IconLayer) throws -> IconDocument {
        try updateSelectedDocument { document in
            document.layers.append(layer)
        }
    }

    @discardableResult
    public func updateLayer(id layerId: String, _ update: (inout IconLayer) throws -> Void) throws -> IconDocument {
        try updateSelectedDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }
            try update(&document.layers[index])
        }
    }

    public func selectDocument(id: String) throws {
        guard documents.contains(where: { $0.id == id }) else {
            throw IconDocumentStoreError.documentNotFound(id)
        }
        selectedDocumentId = id
    }

    public func setExportURL(_ url: URL) {
        lastExportURL = url
        lastError = nil
    }

    public func setError(_ message: String) {
        lastError = message
    }

    public func resetForTests() {
        documents.removeAll()
        selectedDocumentId = nil
        lastExportURL = nil
        lastError = nil
    }
}

public enum IconDocumentStoreError: LocalizedError, Equatable {
    case noSelectedDocument
    case documentNotFound(String)
    case layerNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .noSelectedDocument:
            return "No icon document is selected."
        case .documentNotFound(let id):
            return "Icon document not found: \(id)"
        case .layerNotFound(let id):
            return "Icon layer not found: \(id)"
        }
    }
}
