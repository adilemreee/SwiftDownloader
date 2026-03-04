import SwiftUI

enum Theme {
    // MARK: - Colors
    static let primary = Color(hex: "4F8EF7")
    static let primaryLight = Color(hex: "7AABFF")
    static let primaryDark = Color(hex: "3A6FD8")

    static let accent = Color(hex: "34D399")
    static let accentLight = Color(hex: "6EE7B7")

    static let warning = Color(hex: "F59E0B")
    static let warningLight = Color(hex: "FCD34D")

    static let error = Color(hex: "EF4444")
    static let errorLight = Color(hex: "FCA5A5")

    static let surfacePrimary = Color(hex: "1A1B2E")
    static let surfaceSecondary = Color(hex: "222339")
    static let surfaceTertiary = Color(hex: "2A2B45")
    static let surfaceElevated = Color(hex: "32334D")

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "A0A3BD")
    static let textTertiary = Color(hex: "6B6F8D")

    static let border = Color(hex: "3D3E5C")
    static let borderLight = Color(hex: "4A4B6A")

    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [primary, Color(hex: "6C5CE7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let successGradient = LinearGradient(
        colors: [accent, Color(hex: "10B981")],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let progressGradient = LinearGradient(
        colors: [primary, primaryLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [surfacePrimary, Color(hex: "0F1021")],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Dimensions
    static let cornerRadius: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusLarge: CGFloat = 16

    static let paddingSmall: CGFloat = 8
    static let paddingMedium: CGFloat = 16
    static let paddingLarge: CGFloat = 24

    static let sidebarWidth: CGFloat = 220
    static let rowHeight: CGFloat = 72
    static let menuBarWidth: CGFloat = 360
    static let menuBarHeight: CGFloat = 420

    // MARK: - Shadows
    static let shadowColor = Color.black.opacity(0.3)
    static let shadowRadius: CGFloat = 10

    // MARK: - Animation
    static let springAnimation = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let quickAnimation = Animation.easeInOut(duration: 0.2)
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
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
