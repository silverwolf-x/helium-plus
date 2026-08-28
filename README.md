# Helium Browser 便携版

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/PanDaDaTech/Helium-Portable/main.yml?event=schedule&label=daily%20build)
![GitHub Release](https://img.shields.io/github/v/release/PanDaDaTech/Helium-Portable?display_name=release&logo=googlechrome&label=Helium%2B%2B)
![GitHub Release](https://img.shields.io/github/v/release/Bush2021/chrome_plus?display_name=release&logo=github&label=Chrome%2B%2B)

基于 [Helium Browser](https://github.com/imputnet/helium-windows) 和 [Chrome++](https://github.com/Bush2021/chrome_plus) 构建的便携浏览器。

**致谢原项目 [silverwolf-x/helium-plus](https://github.com/silverwolf-x/helium-plus) 的仓库参考！**
 - 因上游提供的便捷版文件夹顺序原因对我而言不太爽，故 Fork 原项目并在此基础上改用上游的 NSIS 安装包版本提取制作便捷版。

Helium 是一个注重隐私的 Chromium 分支，完全兼容 Chrome 扩展。官方 Windows 版本并非便携设计——用户数据存储在 `C:\Users\[用户名]\AppData\Local` 下。本项目集成 Chrome++（DLL 注入实现便携化及标签页增强），将 Helium 打包为真正的便携浏览器，所有数据保留在程序目录内。

**特性：**
- 便携配置——`Data` 和 `Cache` 目录保留在程序文件夹内
- 标签页增强（双击关闭、滚轮切换标签等）
- 快捷键重映射与老板键支持
- 无需安装，解压即用
- 仅保留 `zh-CN` 和 `en-US` 语言包以缩减体积
- 同时提供 x64 和 arm64 两个架构版本
- Release 使用 7z 格式打包
- 通过 GitHub Actions 每日自动构建

**更新机制：**
- 每天 UTC+8 08:00 检查 [Helium Windows](https://github.com/imputnet/helium-windows) 是否有新版本
- 检测到新版 Helium 时自动构建并发布（同时拉取最新 Chrome++）
- 手动触发时创建草稿 Release
- 版本格式：`{helium_version}+{chrome_plus_version}`

---

## 许可证

GPL-3.0，详见 [LICENSE](LICENSE)。

上游项目均为 GPL-3.0：
- [Helium Windows](https://github.com/imputnet/helium-windows)
- [Chrome++](https://github.com/Bush2021/chrome_plus)

