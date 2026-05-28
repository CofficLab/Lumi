import Foundation

@MainActor
public final class IconDocumentStore: ObservableObject {
    public static let shared = IconDocumentStore()

    @Published public private(set) var documents: [IconDocument] = []
    @Published public var selectedDocumentId: String?
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var lastError: String?
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false

    private var undoStack: [IconDocument] = []
    private var redoStack: [IconDocument] = []

    public init() {}

    public var selectedDocument: IconDocument? {
        guard let selectedDocumentId else { return documents.first }
        return documents.first { $0.id == selectedDocumentId } ?? documents.first
    }

    @discardableResult
    public func createDocument(title: String?, width: Double, height: Double, background: IconPaint) -> IconDocument {
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = IconDocumentSanitizer.sanitized(IconDocument(
            title: trimmedTitle?.isEmpty == false ? trimmedTitle! : "Untitled Icon",
            width: width,
            height: height,
            background: background
        ))
        documents.insert(document, at: 0)
        selectedDocumentId = document.id
        clearHistory()
        lastError = nil
        return document
    }

    @discardableResult
    public func createDocument(from preset: IconPreset, title: String? = nil) -> IconDocument {
        var document = IconDocumentSanitizer.sanitized(preset.makeDocument(title))
        document.createdAt = Date()
        document.updatedAt = document.createdAt
        documents.insert(document, at: 0)
        selectedDocumentId = document.id
        clearHistory()
        lastError = nil
        return document
    }

    @discardableResult
    public func updateSelectedDocument(_ update: (inout IconDocument) throws -> Void) throws -> IconDocument {
        guard let selectedDocumentId, let index = documents.firstIndex(where: { $0.id == selectedDocumentId }) else {
            throw IconDocumentStoreError.noSelectedDocument
        }

        let previous = documents[index]
        var next = previous
        try update(&next)
        next = IconDocumentSanitizer.sanitized(next)
        guard next != previous else {
            lastError = nil
            return previous
        }
        next.updatedAt = Date()
        documents[index] = next
        recordUndo(previous)
        lastError = nil
        return next
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

    @discardableResult
    public func renameLayer(id layerId: String, name: String) throws -> IconDocument {
        try updateLayer(id: layerId) { layer in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            layer.name = trimmed.isEmpty ? layer.name : trimmed
        }
    }

    @discardableResult
    public func duplicateLayer(id layerId: String) throws -> (document: IconDocument, layer: IconLayer) {
        var duplicatedLayer: IconLayer?
        let document = try updateSelectedDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }
            var layer = document.layers[index]
            layer.id = UUID().uuidString
            layer.name = "\(layer.name) Copy"
            layer.transform.translateX += 32
            layer.transform.translateY += 32
            document.layers.insert(layer, at: index + 1)
            duplicatedLayer = layer
        }
        guard let duplicatedLayer else {
            throw IconDocumentStoreError.layerNotFound(layerId)
        }
        return (document, duplicatedLayer)
    }

    @discardableResult
    public func deleteLayer(id layerId: String) throws -> IconDocument {
        try updateSelectedDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }
            document.layers.remove(at: index)
        }
    }

    @discardableResult
    public func moveLayer(id layerId: String, direction: LayerMoveDirection) throws -> IconDocument {
        try updateSelectedDocument { document in
            guard let index = document.layers.firstIndex(where: { $0.id == layerId }) else {
                throw IconDocumentStoreError.layerNotFound(layerId)
            }

            let targetIndex: Int
            switch direction {
            case .backward:
                targetIndex = max(0, index - 1)
            case .forward:
                targetIndex = min(document.layers.count - 1, index + 1)
            }

            guard targetIndex != index else { return }
            let layer = document.layers.remove(at: index)
            document.layers.insert(layer, at: targetIndex)
        }
    }

    @discardableResult
    public func replaceSelectedDocument(_ document: IconDocument) throws -> IconDocument {
        var replacement = IconDocumentSanitizer.sanitized(document)
        if let selectedDocumentId, let index = documents.firstIndex(where: { $0.id == selectedDocumentId }) {
            let previous = documents[index]
            replacement.updatedAt = Date()
            guard replacement != previous else {
                lastError = nil
                return previous
            }
            documents[index] = replacement
            recordUndo(previous)
        } else {
            documents.insert(replacement, at: 0)
            selectedDocumentId = replacement.id
            clearHistory()
        }
        lastError = nil
        return replacement
    }

    @discardableResult
    public func importDocument(_ document: IconDocument) -> IconDocument {
        var imported = IconDocumentSanitizer.sanitized(document)
        imported.id = UUID().uuidString
        imported.createdAt = Date()
        imported.updatedAt = imported.createdAt
        documents.insert(imported, at: 0)
        selectedDocumentId = imported.id
        clearHistory()
        lastError = nil
        return imported
    }

    public func undo() {
        guard let selectedDocumentId,
              let index = documents.firstIndex(where: { $0.id == selectedDocumentId }),
              let previous = undoStack.popLast()
        else { return }

        redoStack.append(documents[index])
        documents[index] = previous
        updateHistoryFlags()
        lastError = nil
    }

    public func redo() {
        guard let selectedDocumentId,
              let index = documents.firstIndex(where: { $0.id == selectedDocumentId }),
              let next = redoStack.popLast()
        else { return }

        undoStack.append(documents[index])
        documents[index] = next
        updateHistoryFlags()
        lastError = nil
    }

    public func selectDocument(id: String) throws {
        guard documents.contains(where: { $0.id == id }) else {
            throw IconDocumentStoreError.documentNotFound(id)
        }
        selectedDocumentId = id
        clearHistory()
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
        clearHistory()
    }

    private func recordUndo(_ previous: IconDocument) {
        undoStack.append(previous)
        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
        redoStack.removeAll()
        updateHistoryFlags()
    }

    private func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateHistoryFlags()
    }

    private func updateHistoryFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

public enum LayerMoveDirection: Equatable, Sendable {
    case backward
    case forward
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
