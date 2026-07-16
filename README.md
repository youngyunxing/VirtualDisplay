<h1 align="center">VirtualDisplay</h1>

<p align="center">
 <strong>English → <a href="README_EN.md">README_EN.md</a></strong>
</p>

<p align="center">
 <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-13.0%2B-000000?logo=apple" alt="macOS"></a>
 <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift"></a>
 <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License"></a>
 <a href="../../releases/tag/v5.2.0"><img src="https://img.shields.io/badge/Release-v5.2.0-orange.svg" alt="Release"></a>
</p>

VirtualDisplay 是一个**极简、轻量**的 macOS 菜单栏工具，使用私有 CoreGraphics API 创建虚拟显示器 专为远程桌面、屏幕共享和无头 Mac 设计

> **痛点**：macOS 在没有物理显示器时，默认只提供模糊的 1080p 虚拟屏，文字发虚、可操作区域小 VirtualDisplay 一键解锁 4K / 8K 任意分辨率，默认开启 HiDPI，远程办公也能获得清晰画质

<p align="center">
 <img src="Screenshots/menu.png" alt="菜单截图">
</p>

## 目录

- [功能特性](#-功能特性)
- [适用场景](#-适用场景)
- [系统要求](#-系统要求)
- [下载安装](#-下载安装)
- [常见问题](#-常见问题)
- [使用示例](#-使用示例)
- [菜单说明](#-菜单说明)
- [HiDPI 与分辨率选择](#-hidpi-与分辨率选择)
- [高刷新率](#-高刷新率)
- [命令行工具 vdctl](#-命令行工具-vdctl)
- [适合人群](#-适合人群)
- [从源码构建](#-从源码构建)
- [赞助支持](#-赞助支持)

## ✨ 功能特性

- **极简轻量**：纯菜单栏运行，无 Dock 图标、无复杂设置面板
- **零配置**：启动即用
- **任意分辨率**：宽度高度自由填写，4K、8K 均可，不受限制
- **支持 HiDPI**：画面更清晰
- **支持高刷新率**：60Hz / 120Hz / 144Hz，不限制刷新率，可自由定制
- **多显示器隔离**：可同时创建多个虚拟显示器，独立管理分辨率预设
- **预设管理**：每个显示器支持添加、编辑、删除、恢复和激活分辨率预设
- **状态记忆**：可临时开启/关闭显示器，状态会在下次启动时恢复
- **命令行友好**：内置 `vdctl`，默认输出 JSON，方便脚本化与 Agent 调用
- **免费开源**：MIT 协议，无需付费或订阅

## 🎯 适用场景

- **远程桌面**：给 UU 远程、RustDesk、VNC、屏幕共享等客户端提供一个固定分辨率的虚拟显示器，画面不会随着你的真实屏幕变来变去
- **配合 UU 远程**：非常适合办公、编码、远程控制 Claude Code / Codex 等 Agent 场景，Mac mini 无头也能获得完整桌面体验
- **平板/手机投屏**：让远程端以它自己的原生分辨率显示，比如 OPPO Pad 3 的 2800×2000
- **多设备隔离**：可以创建多个虚拟显示器，每个对应不同的远程目标，互不干扰
- **Mac mini / 无头 Mac**：不接显示器的 Mac mini 远程连接时，macOS 通常只能给出 1080p 甚至更低的基础分辨率，画面糊、可操作区域小 VirtualDisplay 可以虚拟出一台 4K、8K 或任意分辨率的显示器，刷新率也能自己填（60Hz、120Hz、144Hz 都可以尝试，具体看系统和远程端支持）

## 💻 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel Mac
- 8GB 内存（多 4K 屏建议 16GB）

## 📦 下载安装

1. 从 [Releases](../../releases/latest) 下载 `VirtualDisplay.zip`
2. 解压，把 `VirtualDisplay.app` 拖到「应用程序」文件夹
3. 打开应用，菜单栏会出现显示器图标<br>首次启动会自动开启「开机自启」，如需调整可在主菜单中勾选或取消「开机自启」
4. 菜单栏点击图标 → 选择默认显示器的预设，或添加新显示器 / 自定义分辨率

## ❓ 常见问题

### 提示「无法打开」或「已损坏」

VirtualDisplay 使用 ad-hoc 签名，未经过 Apple 公证，首次运行可能被 Gatekeeper 拦截 在终端执行以下命令移除隔离标记即可：

```bash
xattr -dr com.apple.quarantine /Applications/VirtualDisplay.app
```

也可以在「访达」中右键 `VirtualDisplay.app` →「打开」，然后在弹窗中再次点击「打开」

## 🚀 使用示例

### OPPO Pad 3 远程

OPPO Pad 3 的分辨率是 2800×2000，想让远程端原生素显示：

1. 点击菜单栏图标 → **添加显示器**，命名为 `OPPO_Pad`
2. 展开 `OPPO_Pad` 子菜单 → **添加分辨率**
3. 名称填 `OPPO Pad 3`，宽度 `2800`，高度 `2000`，FPS `60`
4. 保存后点击这个预设选中
5. 在 UU 远程里选择 `OPPO_Pad` 显示器，并选择分辨率 **`1400 × 1000 (HiDPI)`**，远程端即可看到 2800×2000 等效画质

> 默认开启 HiDPI，macOS 内部以 1400×1000 渲染，再放大输出 2800×2000 如果 UU 远程支持 HiDPI 选项，优先选带 HiDPI 标记的逻辑分辨率；不支持时才会直接显示 2800×2000

### 4K 远程

1. 展开任意显示器子菜单 → **添加分辨率**
2. 名称 `4K UHD`，宽度 `3840`，高度 `2160`，FPS `60`
3. 保存并选中
4. 远程端选择该显示器后，优先选带 **HiDPI** 的 `1920 × 1080`；如果客户端不支持 HiDPI，则直接选 `3840 × 2160`

### Mac mini 无头 4K 120Hz

Mac mini 不接显示器时，远程桌面经常只有 1080p 用 VirtualDisplay 可以虚拟一台 4K 高刷屏：

1. 点击菜单栏图标 → **添加显示器**，命名为 `MacMini_4K`
2. 展开子菜单 → **添加分辨率**
3. 名称 `4K 120Hz`，宽度 `3840`，高度 `2160`，FPS `120`
4. 保存并选中
5. 用 VNC / UU 远程 / 屏幕共享连接，选择 `MacMini_4K`，并优先选带 **HiDPI** 的 `1920 × 1080` 分辨率

8K 同理，填 `7680 × 4320` 就行

## 📖 菜单说明

- **物理分辨率**：菜单里显示的大数字，也是远程端实际收到的帧缓冲尺寸 比如 `4K UHD (3840×2160@60 / 1920×1080 HiDPI)`
- **逻辑分辨率**：括号里的 HiDPI 值，macOS 实际渲染 UI 用的尺寸 VirtualDisplay 固定是物理分辨率的一半，所以 `3840×2160` 对应 `1920×1080 HiDPI`
- **FPS**：刷新率 自定义预设时可以自己填，不限 60
- **添加分辨率**：弹窗支持「从模板选择」（内置 iPad Pro / OPPO Pad 3 / MacBook Pro / 4K UHD / 1080p FHD 等），也可以手动填写宽高和 FPS
- **多分辨率模式**：关闭时只能同时选中一个分辨率；开启时可以同时激活多个，它们都会出现在 macOS 显示器设置里，当前输出的是列表第一个，VirtualDisplay 菜单里会以绿色高亮当前实际输出的预设

 举个例子：一个显示器保存了 `4K UHD` 和 `1080p FHD` 两个预设
 - 关闭多分辨率模式：菜单里只能勾选一个 你点 `4K UHD` 就输出 4K，再点 `1080p FHD` 就自动切到 1080p
 - 开启多分辨率模式：两个预设会同时出现在 macOS 的「系统设置 → 显示器」分辨率列表里 你可以直接进系统设置切换；在 VirtualDisplay 菜单里排在第一个的预设是当前实际输出的分辨率
- **开启/关闭显示器**：临时让某个虚拟显示器上线或下线，状态会记住 删除显示器则是彻底移除配置，最后一台不能删
- **显示器名称**：只能用字母、数字、下划线

## 🖥️ HiDPI 与分辨率选择

VirtualDisplay 默认创建的虚拟显示器都是 **HiDPI** 模式

简单来说：

- **物理分辨率**：显示器真实输出的像素数量，也是远程端最终收到的帧缓冲大小
- **逻辑分辨率**：macOS 渲染 UI 时使用的坐标系大小，只有物理分辨率的一半
- macOS 先在逻辑分辨率上渲染，再整体放大 2× 输出到物理分辨率，所以 UI 大小正常、文字和图标却很锐利

举个例子：

| 你添加的预设 | 物理输出 | macOS 内部渲染 | 远程客户端应选 |
|---|---|---|---|
| 4K UHD | 3840 × 2160 | 1920 × 1080 | **1920 × 1080 HiDPI** |
| OPPO Pad 3 | 2800 × 2000 | 1400 × 1000 | **1400 × 1000 HiDPI** |
| 1080p FHD | 1920 × 1080 | 960 × 540 | **960 × 540 HiDPI** |

在 UU 远程、VNC 客户端或 macOS 显示器设置里，你通常会看到两个版本：

1. 带 **HiDPI** 标记的 **逻辑分辨率**（如 `1920 × 1080 HiDPI`）
2. 不带标记的 **物理分辨率**（如 `3840 × 2160`）

**优先选带 HiDPI 标记的逻辑分辨率 ** 这样 macOS 才会按 2× 渲染，远程端实际拿到的是清晰的 4K 帧缓冲

如果远程客户端不支持 HiDPI、只列出物理分辨率，那就直接选物理分辨率 此时远程端收到的仍然是 4K 帧缓冲，只是客户端可能按 1:1 显示，导致 UI 偏小，需要在客户端里再调整缩放

## ⚡ 高刷新率

VirtualDisplay 对 FPS 没有硬性限制，添加分辨率时刷新率可以随便填 只要系统和远程端支持，就能跑出高刷效果

下图是一台 Mac mini 上创建的虚拟显示器，系统信息里显示为 **2880 × 1800 @ 144Hz**，HiDPI 逻辑分辨率为 **1440 × 900**：

![高刷新率截图](Screenshots/high-refresh.png)

## ⌨️ 命令行工具 vdctl

v4.0.0 起，VirtualDisplay 内置 `vdctl` 命令行工具，可用于脚本和 Agent 调用

`vdctl` 依赖菜单栏应用来保活显示器；如果检测到应用没有运行，会自动打开 `/Applications/VirtualDisplay.app`

```bash
# 查看当前状态
vdctl status

# 列出显示器和预设
vdctl list displays
vdctl list presets VirtualDisplay

# 显示器增删改
vdctl add display MacMini_4K
vdctl rename display MacMini_4K MacMini_8K
vdctl toggle display MacMini_4K
vdctl remove display MacMini_4K

# 分辨率预设
vdctl add preset MacMini_4K "4K 120Hz" 3840 2160 120
vdctl activate preset MacMini_4K "4K 120Hz"
vdctl remove preset MacMini_4K "4K 120Hz"

# 多分辨率模式
vdctl set multi-resolution MacMini_4K true

# 导出/导入配置（v5.0.0 起）
vdctl export --path ~/Desktop/vd.json
vdctl export display MacMini_4K --path ~/Desktop/macmini.json
vdctl export preset MacMini_4K "4K 120Hz" --path ~/Desktop/4k120.json
vdctl import --path ~/Desktop/vd.json
vdctl import --path ~/Desktop/vd.json --merge
vdctl import --path ~/Desktop/preset.json --display MacMini_4K

# 导出诊断信息（默认输出到终端，--path 写入文件）
vdctl diagnostics
vdctl diagnostics --path ~/Desktop/diag.txt
```

### 导入/导出配置

v5.0.0 起支持将配置以 JSON 形式导出、导入：

- **导出**：
 - 主菜单「导入配置」下方，每个显示器子菜单有「导出此显示器配置」
 - 预设子菜单有「导出」
 - `vdctl export` 命令行支持完整/显示器/预设三种范围
 - 导出的 JSON 会剥离硬件标识（`vendorID` / `productID` / `serialNumber`），方便安全分享
- **导入**：菜单「导入配置」或 `vdctl import --path`
 - 默认**替换**当前配置，菜单导入时会弹出确认
 - 使用 `--merge` 可合并到当前配置，名称冲突自动加 `_imported` 后缀
 - 导入时会重新生成所有显示器/预设 ID 和硬件标识，避免与现有配置冲突

导出的 JSON 可以直接发给别人，对方用「导入配置」就能恢复

导出 JSON 示例：

```json
{
  "schemaVersion": 1,
  "exportType": "full",
  "exportedAt": "2026-07-09T12:00:00Z",
  "payload": {
    "displays": [
      {
        "name": "MacMini_4K",
        "multiResolutionMode": false,
        "isEnabled": true,
        "activePresetIDs": ["preset-uuid-1"],
        "presets": [
          {
            "id": "preset-uuid-1",
            "name": "4K 120Hz",
            "width": 3840,
            "height": 2160,
            "refreshRate": 120
          }
        ]
      }
    ]
  }
}
```

所有命令默认输出 JSON，错误信息输出到 stderr，并返回非 0 退出码 `vdctl` 安装后位于 `/Applications/VirtualDisplay.app/Contents/MacOS/vdctl`，可以链接到 PATH：

```bash
ln -s /Applications/VirtualDisplay.app/Contents/MacOS/vdctl /usr/local/bin/vdctl
```

## 🎯 适合人群

VirtualDisplay 不限制 FPS、支持高刷新率，也支持 8K 等超高分辨率，只要系统和远程端能处理

**适合谁**：

- 只想轻量、快速地给远程端创建几个固定分辨率的虚拟显示器
- 不想付费、不想配置一堆高级功能
- 需要多显示器隔离，比如一台 Mac 同时服务多个远程设备

**暂不支持的功能**：

- 屏幕旋转
- 亮度调节

如果只需要一个固定分辨率且不想装软件，十几块的 HDMI 诱骗器也是可行方案，但它不提供 HiDPI 和多屏隔离

## 🛠️ 从源码构建

```bash
rm -rf build
xcodebuild build -project VirtualDisplay.xcodeproj -scheme VirtualDisplay -configuration Release -derivedDataPath build CONFIGURATION_BUILD_DIR=build/Release
```

构建产物在 `build/Release/VirtualDisplay.app`，`vdctl` 会被一起打包到 `VirtualDisplay.app/Contents/MacOS/vdctl` 你也可以单独构建 CLI：

```bash
xcodebuild build -project VirtualDisplay.xcodeproj -scheme vdctl -configuration Release -derivedDataPath build CONFIGURATION_BUILD_DIR=build/Release
```

## ☕ 赞助支持

如果 VirtualDisplay 帮到了你，可以请我喝杯蜜雪，支持持续维护：

<p align="center">
 <img src="VirtualDisplay/Resources/donate-qr.png" alt="微信收款码" width="220"><br>
 <sub>微信扫码赞助</sub>
</p>
