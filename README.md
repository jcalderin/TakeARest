# Respite

A native macOS menu-bar app that reminds you to take breaks. No Dock icon, full-screen break overlays across all displays, multiple schedules, launch at login.

Requires macOS 15+.

## Install (prebuilt)

1. Download `Respite-<version>.dmg` from the [latest release](../../releases/latest), open it and drag **Respite** into **Applications**.
2. First launch: the app is not notarized, so macOS blocks it once. Double-click Respite, click **Done**, then open **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.
   Terminal alternative: `xattr -dr com.apple.quarantine /Applications/Respite.app`
3. Enable startup: **menu-bar icon → Preferences → General → Launch at login**.

## Install (from source)

Requires Xcode 16+.

```bash
make install   # build Release, copy to /Applications, add `respite` launcher
respite         # start it (launcher lives in ~/.local/bin)
```

Then enable startup: **menu-bar icon → Preferences → General → Launch at login**.
(Toggle it off/on after each reinstall so the login item points at the new build.)

## Commands

| Command          | Does                                      |
|------------------|-------------------------------------------|
| `make install`   | Build + install to /Applications + launcher |
| `make build`     | Build the Release `.app` only             |
| `make run`       | Launch the installed app                  |
| `make test`      | Run the test suite                        |
| `make uninstall` | Remove app and launcher                   |
| `make clean`     | Delete build artifacts                    |
| `make release VERSION=x.y.z` | Build, package and publish a GitHub release |

## Develop

Open `Respite.xcodeproj` and run with `Cmd+R`. Note: apps launched from Xcode
live in DerivedData, which gets wiped periodically — use `make install` for the
copy you actually run day to day.

## Release

```bash
make release VERSION=1.3.0 RELEASE_FLAGS=--dry-run   # build + package into dist/, publish nothing
make release VERSION=1.3.0                           # bump Info.plist, tag v1.3.0, push, create GitHub release
```

The script (`scripts/release.sh`) needs a clean tree on `main` and a `gh` login
with push access to the repo. It uploads `Respite-<version>.zip`, `Respite-<version>.dmg`
and `SHA256SUMS.txt`. The app is ad-hoc signed (no Apple Developer ID), which is
why users need the one-time **Open Anyway** step above.

## License

MIT. See [LICENSE](LICENSE).
