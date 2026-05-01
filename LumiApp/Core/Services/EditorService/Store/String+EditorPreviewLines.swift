import Foundation

extension String {
    func getFirstLines(_ count: Int) -> String? {
        var lines = 0
        for (idx, char) in self.enumerated() {
            if char == "\n" {
                lines += 1
                if lines >= count {
                    let index = self.index(self.startIndex, offsetBy: idx)
                    return String(self[..<index])
                }
            }
        }
        return nil
    }

    func getLastLines(_ count: Int) -> String? {
        var lines = 0
        for (idx, char) in self.enumerated().reversed() {
            if char == "\n" {
                lines += 1
                if lines >= count {
                    let index = self.index(self.startIndex, offsetBy: idx + 1)
                    return String(self[index...])
                }
            }
        }
        return nil
    }
}
