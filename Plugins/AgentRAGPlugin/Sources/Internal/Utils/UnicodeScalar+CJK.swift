import Foundation

extension UnicodeScalar {
    /// 是否为中日韩（CJK）字符
    public var isCJK: Bool {
        switch value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF:
            return true
        default:
            return false
        }
    }
}
