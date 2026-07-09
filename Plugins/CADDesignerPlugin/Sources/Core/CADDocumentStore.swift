import Foundation

@MainActor
public final class CADDocumentStore: ObservableObject {
    public static let shared = CADDocumentStore()

    @Published public private(set) var documents: [CADDocument] = []
    @Published public var selectedDocumentId: String?
    @Published public var selectedComponentId: String?
    @Published public private(set) var lastExportURL: URL?
    @Published public private(set) var lastError: String?
    @Published public private(set) var canUndo = false
    @Published public private(set) var canRedo = false

    private var undoStack: [CADDocument] = []
    private var redoStack: [CADDocument] = []

    public init() {}

    public var selectedDocument: CADDocument? {
        guard let selectedDocumentId else { return documents.first }
        return documents.first { $0.id == selectedDocumentId } ?? documents.first
    }

    public var selectedComponent: CADComponent? {
        guard let selectedComponentId, let document = selectedDocument else { return nil }
        return document.component(id: selectedComponentId)
    }

    // MARK: - Document Lifecycle

    @discardableResult
    public func createDocument(name: String?) -> CADDocument {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let document = CADDocument(
            name: (trimmed?.isEmpty == false) ? trimmed! : "Untitled Project"
        )
        documents.insert(document, at: 0)
        selectedDocumentId = document.id
        selectedComponentId = nil
        clearHistory()
        lastError = nil
        return document
    }

    @discardableResult
    public func replaceSelectedDocument(_ document: CADDocument) throws -> CADDocument {
        var replacement = document
        if let selectedDocumentId, let index = documents.firstIndex(where: { $0.id == selectedDocumentId }) {
            let previous = documents[index]
            replacement.modifiedAt = Date()
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
    public func importDocument(_ document: CADDocument) -> CADDocument {
        var imported = document
        imported.id = UUID().uuidString
        imported.createdAt = Date()
        imported.modifiedAt = imported.createdAt
        documents.insert(imported, at: 0)
        selectedDocumentId = imported.id
        selectedComponentId = nil
        clearHistory()
        lastError = nil
        return imported
    }

    // MARK: - Component Editing

    @discardableResult
    public func updateSelectedDocument(_ update: (inout CADDocument) throws -> Void) throws -> CADDocument {
        guard let selectedDocumentId,
              let index = documents.firstIndex(where: { $0.id == selectedDocumentId }) else {
            throw CADDocumentStoreError.noSelectedDocument
        }

        let previous = documents[index]
        var next = previous
        try update(&next)
        guard next != previous else {
            lastError = nil
            return previous
        }
        next.modifiedAt = Date()
        documents[index] = next
        recordUndo(previous)
        lastError = nil
        return next
    }

    @discardableResult
    public func addComponent(_ component: CADComponent) throws -> CADComponent {
        let result = try updateSelectedDocument { document in
            document.components.append(component)
        }
        selectedComponentId = component.id
        return component
    }

    @discardableResult
    public func addComponents(_ components: [CADComponent]) throws -> [CADComponent] {
        try updateSelectedDocument { document in
            document.components.append(contentsOf: components)
        }
        selectedComponentId = components.last?.id
        return components
    }

    @discardableResult
    public func updateComponent(id componentId: String, _ update: (inout CADComponent) throws -> Void) throws -> CADDocument {
        try updateSelectedDocument { document in
            guard let index = document.componentIndex(id: componentId) else {
                throw CADDocumentStoreError.componentNotFound(componentId)
            }
            try update(&document.components[index])
        }
    }

    @discardableResult
    public func deleteComponent(id componentId: String) throws -> CADDocument {
        let document = try updateSelectedDocument { document in
            guard let index = document.componentIndex(id: componentId) else {
                throw CADDocumentStoreError.componentNotFound(componentId)
            }
            document.components.remove(at: index)
            // 同步移除涉及该组件的连接关系
            document.connections.removeAll {
                $0.fromComponentID == componentId || $0.toComponentID == componentId
            }
        }
        if selectedComponentId == componentId {
            selectedComponentId = nil
        }
        return document
    }

    @discardableResult
    public func addConnection(_ edge: ConnectionEdge) throws -> CADDocument {
        try updateSelectedDocument { document in
            document.connections.append(edge)
        }
    }

    @discardableResult
    public func deleteConnection(id edgeId: String) throws -> CADDocument {
        try updateSelectedDocument { document in
            document.connections.removeAll { $0.id == edgeId }
        }
    }

    public func selectComponent(id: String?) {
        selectedComponentId = id
    }

    // MARK: - Undo / Redo

    public func undo() {
        guard let selectedDocumentId,
              let index = documents.firstIndex(where: { $0.id == selectedDocumentId }),
              let previous = undoStack.popLast() else { return }
        redoStack.append(documents[index])
        documents[index] = previous
        updateHistoryFlags()
        lastError = nil
    }

    public func redo() {
        guard let selectedDocumentId,
              let index = documents.firstIndex(where: { $0.id == selectedDocumentId }),
              let next = redoStack.popLast() else { return }
        undoStack.append(documents[index])
        documents[index] = next
        updateHistoryFlags()
        lastError = nil
    }

    // MARK: - Status

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
        selectedComponentId = nil
        lastExportURL = nil
        lastError = nil
        clearHistory()
    }

    // MARK: - Private

    private func recordUndo(_ previous: CADDocument) {
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

public enum CADDocumentStoreError: LocalizedError, Equatable {
    case noSelectedDocument
    case componentNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .noSelectedDocument:
            return "No CAD document is selected."
        case .componentNotFound(let id):
            return "CAD component not found: \(id)"
        }
    }
}
