import SwiftUI

// MARK: - Typography Modifiers

/// Hero text — large countdown numbers on the overlay
struct RespiteHeroStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DesignTokens.fontSizeHero, weight: .ultraLight, design: .rounded))
            .foregroundStyle(DesignTokens.overlayText)
    }
}

/// Title text — section headings, overlay messages
struct RespiteTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DesignTokens.fontSizeTitle, weight: .medium, design: .rounded))
    }
}

/// Subtitle text — tab headers, secondary headings
struct RespiteSubtitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DesignTokens.fontSizeSubtitle, weight: .regular, design: .default))
    }
}

/// Body text — descriptions, labels
struct RespiteBodyStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DesignTokens.fontSizeBody, weight: .regular, design: .default))
    }
}

/// Caption text — hints, keyboard shortcuts, secondary info
struct RespiteCaptionStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DesignTokens.fontSizeCaption, weight: .regular, design: .default))
            .foregroundStyle(DesignTokens.secondaryText)
    }
}

// MARK: - View Extensions

extension View {

    /// Large countdown numbers for the break overlay
    func respiteHero() -> some View {
        modifier(RespiteHeroStyle())
    }

    /// Section headings and overlay messages
    func respiteTitle() -> some View {
        modifier(RespiteTitleStyle())
    }

    /// Tab headers and secondary headings
    func respiteSubtitle() -> some View {
        modifier(RespiteSubtitleStyle())
    }

    /// Standard body text
    func respiteBody() -> some View {
        modifier(RespiteBodyStyle())
    }

    /// Hints, shortcuts, and secondary information
    func respiteCaption() -> some View {
        modifier(RespiteCaptionStyle())
    }
}

// MARK: - Card Style

/// Consistent card container used across preferences tabs
struct RespiteCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignTokens.spacingMD)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSM))
    }
}

extension View {
    /// Wraps content in a consistent card container
    func respiteCard() -> some View {
        modifier(RespiteCardStyle())
    }
}
