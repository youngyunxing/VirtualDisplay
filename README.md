# VirtualDisplay

一个轻量级 macOS 菜单栏应用，使用私有 CoreGraphics API 创建虚拟显示器。

A lightweight macOS menu bar app that creates virtual displays using private CoreGraphics API.

---

## 特性

- 无 Dock 图标，纯菜单栏运行
- 启动后自动创建虚拟显示器
- 针对常用设备预设分辨率：
  - OPPO Pad 3（2800×2000）
  - MacBook M1 13 寸（2560×1600 原生 / 1440×900 缩放）
  - 通用 4K UHD / 1080p FHD
- 默认以 HiDPI 模式渲染：逻辑分辨率与菜单选择一致，内部帧缓冲为 2× 物理分辨率，画面更清晰
- 右键菜单栏图标即可退出

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel Mac

## 下载

当前最新版本：[v1.0.1](../../releases/tag/v1.0.1)

从 [Releases](../../releases/latest) 下载最新版 `VirtualDisplay.zip`，解压后拖入「应用程序」文件夹。

## 使用

1. 打开 `VirtualDisplay.app`，菜单栏出现显示器图标。
2. 点击菜单栏图标，选择要远程的设备预设（如 **OPPO Pad 3**、**MacBook M1 13 寸**）。
3. 应用会默认以 **HiDPI 模式** 创建虚拟显示器：逻辑分辨率与菜单选择一致，内部帧缓冲为该分辨率的 2×（如 1440×900 逻辑对应 2880×1800 物理）。远程端将按 2× 帧缓冲接收画面。
4. 若远程端画面显示过小，请在远程客户端（如 UU 远程）调整其显示缩放或适配设置，而非在 VirtualDisplay 中关闭 HiDPI。
5. 在控制端（如 UU 远程）连接 Mac，虚拟显示器即匹配目标设备屏幕。
6. 点击菜单栏图标选择「退出」，即可关闭虚拟显示器。

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
