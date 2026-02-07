import Foundation
import Combine
import SwiftUI

@MainActor
class TerminalSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var title: String = "Terminal"
    @Published var output: NSAttributedString = NSAttributedString()
    @Published var isConnected: Bool = false
    
    private let pty = PseudoTerminal()
    private let parser = ANSIParser()
    private var rawData = Data() // Buffer
    
    init() {
        setupPTY()
    }
    
    private func setupPTY() {
        pty.onOutput = { [weak self] data in
            guard let self = self else { return }
            self.handleOutput(data)
        }
        
        pty.onProcessTerminated = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.appendSystemMessage("Session ended.")
            }
        }
        
        do {
            try pty.start()
            isConnected = true
        } catch {
            appendSystemMessage("Failed to start terminal: \(error)")
        }
    }
    
    private func handleOutput(_ data: Data) {
        // Append to raw buffer and re-parse?
        // For efficiency, we should append to attributed string directly if parser supports incremental.
        // Our simple parser parses whole string.
        // Let's just append raw data and parse only the new chunk?
        // No, because ANSI codes can span chunks.
        
        // MVP: Append to rawData and re-parse everything (slow but simple)
        // Optimization: Keep a clean buffer.
        
        rawData.append(data)
        
        // Limit buffer size
        if rawData.count > 1_000_000 {
            rawData = rawData.suffix(500_000)
        }
        
        self.output = parser.parse(data: rawData)
    }
    
    func sendInput(_ data: Data) {
        guard isConnected else { return }
        pty.write(data)
    }
    
    private func appendSystemMessage(_ text: String) {
        let str = "\n[Lumi Terminal] \(text)\n"
        if let data = str.data(using: .utf8) {
            rawData.append(data)
            self.output = parser.parse(data: rawData)
        }
    }
    
    func terminate() {
        pty.terminate()
    }
}
