import SwiftUI

enum AppTheme {
    static let background = Color(hex: "0D0D0D")
    static let cardBackground = Color(hex: "1A1A1A")
    static let secondaryBackground = Color(hex: "2A2A2A")
    static let gold = Color(hex: "C9A84C")
    static let goldLight = Color(hex: "E8D5A3")
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "999999")
    static let textMuted = Color(hex: "666666")
    static let border = Color(hex: "333333")
    static let destructive = Color(hex: "E74C3C")
    static let success = Color(hex: "2ECC71")

    static let directorColors: [Color] = [
        Color(hex: "C9A84C"), // Gold - CEO
        Color(hex: "4A90D9"), // Blue - Financial Rationalist
        Color(hex: "E74C3C"), // Red - Devil's Advocate
        Color(hex: "8C8F94"), // Cool steel grey - COO (operations)
    ]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
