import SwiftUI
import AppKit

extension Color {

    /// Create a Color from a hex string like "#FF5733" or "FF5733".
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// Convert a Color to a hex string like "#FF5733".
    /// Returns nil if the color can't be converted to sRGB.
    func toHex() -> String? {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return nil }

        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
