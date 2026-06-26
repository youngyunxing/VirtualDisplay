# VirtualDisplay

一个轻量级 macOS 菜单栏应用，使用私有 CoreGraphics API 创建虚拟显示器。

A lightweight macOS menu bar app that creates virtual displays using private CoreGraphics API.

---

## 特性

- 无 Dock 图标，纯菜单栏运行
- 启动后自动创建虚拟显示器
- 针对常用设备预设分辨率：
  - OPPO Pad 3（2800×2000）
  - MacBook M1 13 寸（2560×1600 原生 / 2880×1800 缩放）
  - 通用 4K UHD / 1080p FHD
- 右键菜单栏图标即可退出

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel Mac

## 下载

当前最新版本：[v1.0.0](../../releases/tag/v1.0.0)

从 [Releases](../../releases/latest) 下载最新版 `VirtualDisplay.zip`，解压后拖入「应用程序」文件夹。

## 使用

1. 打开 `VirtualDisplay.app`，菜单栏出现显示器图标。
2. 点击菜单栏图标，选择要远程的设备预设（如 **OPPO Pad 3**、**MacBook M1 13 寸**）。
3. 应用会自动切换到该设备的最佳分辨率。推荐选择 HiDPI 选项，macOS 会以物理分辨率渲染，画面更清晰。
4. 在控制端（如 UU 远程）连接 Mac，虚拟显示器即匹配目标设备屏幕。
5. 点击菜单栏图标选择「退出」，即可关闭虚拟显示器。

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
