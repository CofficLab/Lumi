import SwiftUI
import AppKit
import Combine

@MainActor
class TextActionMenuController {
    static let shared = TextActionMenuController()
    
    private var window: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupBindings()
    }
    
    private func setupBindings() {
        TextSelectionManager.shared.$selectedText
            .combineLatest(TextSelectionManager.shared.$selectionRect)
            .sink { [weak self] text, rect in
                if let text = text, let rect = rect {
                    self?.show(text: text, at: rect.origin)
                } else {
                    self?.hide()
                }
            }
            .store(in: &cancellables)
    }
    
    private func show(text: String, at point: CGPoint) {
        if window == nil {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isOpaque = false
            window = panel
        }
        
        let contentView = ActionMenuView(text: text) { actionType in
            let action = TextAction(type: actionType, text: text)
            action.perform()
            self.hide()
            // Also clear selection in manager so it doesn't pop up again immediately
            TextSelectionManager.shared.selectedText = nil
        }
        
        window?.contentView = NSHostingView(rootView: contentView)
        
        // Calculate size
        let size = window?.contentView?.fittingSize ?? CGSize(width: 150, height: 70)
        let frame = CGRect(x: point.x, y: point.y + 20, width: size.width, height: size.height) // Offset slightly up/down
        
        window?.setFrame(frame, display: true)
        window?.orderFront(nil)
    }
    
    private func hide() {
        window?.orderOut(nil)
    }
}
