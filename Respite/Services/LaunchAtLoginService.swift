import ServiceManagement

/// Wraps SMAppService for launch-at-login functionality.
///
/// Always reads the canonical state from SMAppService.mainApp.status
/// rather than persisting a boolean — the user can toggle login items
/// externally via System Settings > General > Login Items.
enum LaunchAtLoginService {

    /// Whether the app is currently registered to launch at login.
    /// Always reads from the system — never cached.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register the app to launch at login.
    /// - Throws: If registration fails (e.g., sandbox issue, missing entitlement).
    static func register() throws {
        try SMAppService.mainApp.register()
    }

    /// Unregister the app from login items.
    /// - Throws: If unregistration fails.
    static func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    /// Toggle login item registration.
    /// - Parameter enabled: Whether the app should launch at login.
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try register()
            } else {
                try unregister()
            }
        } catch {
            print("LaunchAtLoginService: failed to \(enabled ? "register" : "unregister"): \(error)")
        }
    }

    /// Human-readable status for debugging.
    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            "Enabled"
        case .notRegistered:
            "Not registered"
        case .requiresApproval:
            "Requires approval in System Settings"
        case .notFound:
            "Not found"
        @unknown default:
            "Unknown"
        }
    }
}
