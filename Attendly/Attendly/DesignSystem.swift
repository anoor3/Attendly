import SwiftUI

enum AttendlyDesignSystem {
    enum Colors {
        static let background = Color.white
        static let card = Color.white
        static let primaryGradient = Gradient(colors: [Color(red: 0.145, green: 0.388, blue: 0.922), Color(red: 0.309, green: 0.275, blue: 0.898)])
        static let success = Color(red: 0.063, green: 0.725, blue: 0.506)
        static let warning = Color(red: 0.961, green: 0.619, blue: 0.043)
        static let danger = Color(red: 0.937, green: 0.267, blue: 0.267)
        static let info = Color(red: 0.055, green: 0.647, blue: 0.914)
    }

    enum Shadows {
        static let card = ShadowStyle(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 12)
    }

    enum Spacing {
        static let large: CGFloat = 32
        static let medium: CGFloat = 24
        static let small: CGFloat = 16
    }

    static func gradientButtonBackground() -> LinearGradient {
        LinearGradient(gradient: Colors.primaryGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

struct ShadowStyle {
    var color: Color
    var radius: CGFloat
    var x: CGFloat
    var y: CGFloat
}

extension View {
    func shadowStyle(_ style: ShadowStyle) -> some View {
        shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
