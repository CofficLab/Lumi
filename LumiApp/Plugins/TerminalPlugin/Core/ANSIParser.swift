import Foundation
import AppKit

class ANSIParser {
    // Basic parser that strips ANSI codes and handles basic colors
    // In a real iTerm2 clone, this would be a complex state machine (like libvterm)
    // For MVP, we will just strip escape codes or handle simple SGR (colors)
    // Actually, handling colors is important for "iTerm2-like".
    
    // We will use regex for a very basic implementation to separate text from codes.
    
    func parse(data: Data) -> NSAttributedString {
        guard let string = String(data: data, encoding: .utf8) else { return NSAttributedString() }
        
        let result = NSMutableAttributedString()
        
        // Simple regex to find ESC [ ... m sequences
        // This is NOT a full VT100 parser, just a quick hack for colors
        // Full parser requires a lot of code.
        
        // Strategy: Split by ESC
        let components = string.components(separatedBy: "\u{1B}[")
        
        if let first = components.first {
            result.append(NSAttributedString(string: first, attributes: defaultAttributes))
        }
        
        for i in 1..<components.count {
            let part = components[i]
            // part looks like "31mHello" or "0mReset"
            // Find 'm'
            if let mIndex = part.firstIndex(of: "m") {
                let codeString = part[..<mIndex]
                let text = part[part.index(after: mIndex)...]
                
                // Parse code (e.g. "31" or "1;31")
                let codes = codeString.split(separator: ";").compactMap { Int($0) }
                let attrs = attributes(for: codes)
                
                result.append(NSAttributedString(string: String(text), attributes: attrs))
            } else {
                // Unknown sequence or incomplete, just append raw?
                // Or maybe it's not an SGR code (e.g. K, J, H)
                // For now, ignore unknown sequences to avoid garbage
            }
        }
        
        return result
    }
    
    private var defaultAttributes: [NSAttributedString.Key: Any] {
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.textColor
        ]
    }
    
    private func attributes(for codes: [Int]) -> [NSAttributedString.Key: Any] {
        var attrs = defaultAttributes
        
        for code in codes {
            switch code {
            case 0: // Reset
                attrs = defaultAttributes
            case 1: // Bold
                if let font = attrs[.font] as? NSFont {
                    attrs[.font] = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                }
            case 30...37: // Foreground colors
                attrs[.foregroundColor] = ansiColor(code - 30)
            case 90...97: // Bright foreground
                attrs[.foregroundColor] = ansiColor(code - 90, bright: true)
            default:
                break
            }
        }
        return attrs
    }
    
    private func ansiColor(_ index: Int, bright: Bool = false) -> NSColor {
        let colors: [NSColor] = [
            .black, .red, .green, .yellow, .blue, .magenta, .cyan, .white
        ]
        guard index >= 0 && index < colors.count else { return .textColor }
        let color = colors[index]
        return bright ? color.withAlphaComponent(1.0) : color.withAlphaComponent(0.8) // Simplified
    }
}
