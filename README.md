# Respite

A native macOS menu-bar app that reminds you to take breaks. No Dock icon, full-screen break overlays across all displays, multiple schedules, launch at login.

Requires macOS 15+ and Xcode 16+.

## Install

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

## Develop

Open `Respite.xcodeproj` and run with `Cmd+R`. Note: apps launched from Xcode
live in DerivedData, which gets wiped periodically — use `make install` for the
copy you actually run day to day.

## License

MIT. See [LICENSE](LICENSE).
