import Foundation

extension String {
    /// Removes leading and trailing whitespace and newlines.
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Returns the number of words in the string.
    var wordCount: Int {
        return self.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    /// Returns the string truncated to the specified length, appending "..." if truncated.
    func truncated(to length: Int) -> String {
        if length <= 0 {
            return ""
        }
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + "..."
    }
}