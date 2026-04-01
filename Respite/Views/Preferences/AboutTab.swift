import SwiftUI

/// About tab — app info, version, credits, links.
struct AboutTab: View {

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: DesignTokens.spacingXL) {
            Spacer()

            // App Icon & Name
            VStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignTokens.primaryBlue)

                Text("Respite")
                    .font(.system(size: 28, weight: .light, design: .rounded))

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Description
            Text("A gentle break reminder that helps you maintain healthy screen habits.")
                .respiteBody()
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            // Links
            VStack(spacing: DesignTokens.spacingXS) {
                Link(destination: URL(string: "https://github.com/cholas/respite")!) {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .frame(width: 16)
                        Text("Source Code on GitHub")
                    }
                    .font(.caption)
                }

                Link(destination: URL(string: "https://github.com/cholas/respite/issues")!) {
                    HStack(spacing: DesignTokens.spacingXS) {
                        Image(systemName: "exclamationmark.bubble")
                            .frame(width: 16)
                        Text("Report an Issue")
                    }
                    .font(.caption)
                }
            }

            Spacer()

            // Footer
            VStack(spacing: 4) {
                Text("Made with care for your well-being")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("Open source under the MIT License")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, DesignTokens.spacingSM)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
