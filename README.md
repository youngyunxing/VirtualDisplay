# VirtualDisplay

一个轻量级 macOS 菜单栏应用，使用私有 CoreGraphics API 创建虚拟显示器。

A lightweight macOS menu bar app that creates virtual displays using private CoreGraphics API.

---

## 特性

- 无 Dock 图标，纯菜单栏运行
- 启动后自动创建虚拟显示器
- 针对常用设备预设分辨率：
  - 4K UHD 3840×2160（1920×1080 HiDPI）
  - 1080p FHD 1920×1080（960×540 HiDPI）
  - MacBook 经典 13 寸原生 2560×1600（1280×800 HiDPI）
  - MacBook 经典 13 寸缩放 2880×1800（1440×900 HiDPI）
  - OPPO Pad 3 2800×2000（1400×1000 HiDPI）
- 默认以 HiDPI 模式渲染：设备名后为物理输出分辨率，括号内为 HiDPI 逻辑分辨率，画面更清晰
- 点击菜单栏图标：打开统一面板，选择/切换分辨率预设、增删改查分辨率、切换设置
- 「多分辨率模式」开关放在同一面板底部
- 「多分辨率模式」开启时可同时激活多个分辨率；关闭时只能激活一个
- 所有分辨率预设均支持编辑、删除；可添加自定义分辨率（名称、宽度、高度、刷新率 FPS）
- 提供「恢复默认预设」功能，一键恢复内置分辨率

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel Mac

## 下载

当前最新版本：[v2.2.0](../../releases/tag/v2.2.0)

从 [Releases](../../releases/latest) 下载最新版 `VirtualDisplay.zip`，解压后拖入「应用程序」文件夹。

## 使用

1. 打开 `VirtualDisplay.app`，菜单栏出现显示器图标。
2. **点击**菜单栏图标打开统一面板：
   - 直接点击预设即可选中/取消（单分辨率模式选新取消旧，多分辨率模式可多选）。
   - 悬停在任意预设上可展开子菜单，进行「编辑...」或「删除」。
   - 点击菜单底部的 **添加分辨率...**，输入名称、宽度、高度、刷新率（FPS）即可新增预设。
   - 点击 **恢复默认预设** 可一键恢复内置分辨率（不会删除你已添加的预设）。
   - 勾选或取消 **单分辨率模式** 切换单选/多选行为。
3. 应用会默认以 **HiDPI 模式** 创建虚拟显示器：菜单中设备名后面是物理输出分辨率（远程端实际接收的帧缓冲），括号内是 HiDPI 逻辑分辨率（macOS UI 渲染使用的分辨率）。例如 **1080p FHD 1920×1080（960×540 HiDPI）** 物理输出 `1920×1080`、逻辑 `960×540`；**MacBook M1 13 寸缩放 2880×1800（1440×900 HiDPI）** 物理输出 `2880×1800`、逻辑 `1440×900`。
5. 若远程端画面显示过小，请在远程客户端（如 UU 远程）调整其显示缩放或适配设置。
6. 在面板底部选择「退出」，即可关闭虚拟显示器。

## 从源码构建

```bash
xcodebuild -project VirtualDisplay.xcodeproj -scheme VirtualDisplay -configuration Release build
```

构建产物位于：

```bash
build/Products/Release/VirtualDisplay.app
```

## License

MIT
