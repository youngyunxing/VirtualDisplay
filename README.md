# VirtualDisplay

一个轻量级 macOS 菜单栏应用，使用私有 CoreGraphics API 创建虚拟显示器。

A lightweight macOS menu bar app that creates virtual displays using private CoreGraphics API.

---

## 特性

- 无 Dock 图标，纯菜单栏运行
- 启动后自动创建虚拟显示器
- 针对常用设备预设分辨率：
  - OPPO Pad 3 2800×2000（1400×1000 HiDPI）
  - MacBook M1 13 寸原生 2560×1600（1280×800 HiDPI）
  - MacBook M1 13 寸缩放 2880×1800（1440×900 HiDPI）
  - 4K UHD 3840×2160（1920×1080 HiDPI）
  - 1080p FHD 1920×1080（960×540 HiDPI）
- 默认以 HiDPI 模式渲染：设备名后为物理输出分辨率，括号内为 HiDPI 逻辑分辨率，画面更清晰
- 左键点击菜单栏图标：选择/切换分辨率预设
- 右键点击菜单栏图标：打开设置菜单，切换「单分辨率模式」
- 「单分辨率模式」开启时只能激活一个分辨率；关闭时可同时激活多个分辨率，所有选中的分辨率会作为一个虚拟显示器的可用模式列出

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel Mac

## 下载

当前最新版本：[v2.0.0](../../releases/tag/v2.0.0)

从 [Releases](../../releases/latest) 下载最新版 `VirtualDisplay.zip`，解压后拖入「应用程序」文件夹。

## 使用

1. 打开 `VirtualDisplay.app`，菜单栏出现显示器图标。
2. **左键点击**菜单栏图标，选择要远程的设备预设（如 **OPPO Pad 3 2800×2000（1400×1000 HiDPI）**、**MacBook M1 13 寸缩放 2880×1800（1440×900 HiDPI）**）。
   - 开启「单分辨率模式」时，只能同时激活一个预设；选择新预设会自动取消旧预设。
   - 关闭「单分辨率模式」时，可同时选中多个预设；再次点击已选中的预设可取消它。所有选中的预设会作为同一个虚拟显示器的可用分辨率模式，可在 macOS 显示器设置中切换当前使用的分辨率。
3. **右键点击**菜单栏图标，打开设置菜单，勾选或取消「单分辨率模式」。
4. 应用会默认以 **HiDPI 模式** 创建虚拟显示器：菜单中设备名后面是物理输出分辨率（远程端实际接收的帧缓冲），括号内是 HiDPI 逻辑分辨率（macOS UI 渲染使用的分辨率）。例如 **1080p FHD 1920×1080（960×540 HiDPI）** 物理输出 `1920×1080`、逻辑 `960×540`；**MacBook M1 13 寸缩放 2880×1800（1440×900 HiDPI）** 物理输出 `2880×1800`、逻辑 `1440×900`。
5. 若远程端画面显示过小，请在远程客户端（如 UU 远程）调整其显示缩放或适配设置。
6. 在控制端（如 UU 远程）连接 Mac，虚拟显示器即匹配目标设备屏幕。
7. 在设置菜单或预设菜单底部选择「退出」，即可关闭虚拟显示器。

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
