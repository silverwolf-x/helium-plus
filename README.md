# Helium Browser Portable Edition

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/Silverwolf-x/helium-plus/main.yml?event=schedule&label=daily%20build)
![GitHub Release](https://img.shields.io/github/v/release/Silverwolf-x/helium-plus?display_name=release&logo=googlechrome&label=Helium%2B%2B)
![GitHub Release](https://img.shields.io/github/v/release/Bush2021/chrome_plus?display_name=release&logo=github&label=Chrome%2B%2B)

A portable browser built on [Helium Browser](https://github.com/imputnet/helium-windows) and [Chrome++](https://github.com/Bush2021/chrome_plus).

Helium is a privacy-focused Chromium fork fully compatible with Chrome extensions. The official Windows build is not portable — user data is stored under `C:\Users\[Name]\AppData\Local`. This project integrates Chrome++ (DLL injection for portability and tab enhancements) to package Helium as a truly portable browser, keeping all data within its own directory.

Thanks to [PanDaDaTech](https://github.com/PanDaDaTech) for their [fork](https://github.com/PanDaDaTech/Helium-Portable), which served as a reference.

**Features:**
- Portable profile — `Data` and `Cache` directories stay inside the app folder
- Tab enhancements (double-click to close, scroll to switch tabs, etc.)
- Hotkey remapping and boss-key support
- No installation required — run from any folder
- Only `zh-CN` and `en-US` locale packs included to reduce size
- Automated daily builds via GitHub Actions

**Update cycle:**
- Checks [Helium Windows](https://github.com/imputnet/helium-windows) for new releases every day at 08:00 UTC+8
- Automatically builds and publishes when a new Helium version is detected (always pulls the latest Chrome++ at the same time)
- Manual trigger creates a draft release
- Version format: `{helium_version}+{chrome_plus_version}`


---

## License

GPL-3.0. See [LICENSE](LICENSE).

Both source projects are GPL-3.0:
- [Helium Windows](https://github.com/imputnet/helium-windows)
- [Chrome++](https://github.com/Bush2021/chrome_plus)
