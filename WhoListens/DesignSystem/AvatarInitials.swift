import Foundation

enum AvatarInitials {
    static func forName(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        if words.count >= 2 {
            return String(words.prefix(2).compactMap(\.first)).uppercased()
        }
        return String(words.first?.prefix(2) ?? "?").uppercased()
    }
}
