# VirtualDisplay

![菜单截图](Screenshots/menu.png)

VirtualDisplay 是一个**极简、轻量**的 macOS 菜单栏小工具，用私有 CoreGraphics API 创建虚拟显示器。没有复杂的设置面板，也没有后台服务，常驻菜单栏，点一下就能管理多个虚拟显示器。适合远程桌面、屏幕共享，以及给没有接显示器的 Mac 当主屏用。

A lightweight macOS menu bar app that creates virtual displays using private CoreGraphics APIs, mainly for remote desktop and headless setups.

---

## 有什么用

- **远程桌面**：给 UU 远程、RustDesk、VNC 等客户端提供一个固定分辨率的虚拟显示器，画面不会随着你的真实屏幕变来变去。
- **平板/手机投屏**：让远程端以它自己的原生分辨率显示，比如 OPPO Pad 3 的 2800×2000。
- **多设备隔离**：可以创建多个虚拟显示器，每个对应不同的远程目标，互不干扰。
- **Mac mini / Headless Mac**：不接显示器的 Mac mini 远程连接时，macOS 通常只能给出 1080p 甚至更低的基础分辨率，画面糊、可操作区域小。VirtualDisplay 可以虚拟出一台 4K、8K 或任意分辨率的显示器，刷新率也能自己写（60Hz、120Hz、144Hz 都可以尝试，具体看系统和远程端支持）。

当前版本：[v3.0.0](../../releases/tag/v3.0.0)

---

## 安装

1. 从 [Releases](../../releases/latest) 下载 `VirtualDisplay.zip`。
2. 解压，把 `VirtualDisplay.app` 拖到「应用程序」文件夹。
3. 打开后会在菜单栏出现显示器图标。

系统要求：macOS 13.0+，Apple Silicon 或 Intel Mac。

## 设置开机启动

VirtualDisplay 默认只在菜单栏运行，没有 Dock 图标。如果你想开机后自动创建虚拟显示器，可以把它加入系统登录项：

**macOS Ventura 及更新版本：**

1. 打开「系统设置」→「通用」→「登录项」。
2. 在「登录时打开」下方点击 **+**。
3. 进入「应用程序」，选中 `VirtualDisplay.app`，点击「打开」。

**macOS Monterey 及更早版本：**

1. 打开「系统偏好设置」→「用户与群组」。
2. 选择你的用户，点击「登录项」标签页。
3. 点击 **+**，选中 `VirtualDisplay.app`，点击「添加」。

加入后，每次开机或登录系统，菜单栏会自动出现 VirtualDisplay 图标，并按照上次保存的状态开启虚拟显示器。

---

## 使用示例

### OPPO Pad 3 远程

OPPO Pad 3 的分辨率是 2800×2000，想让远程端原生素显示：

1. 点击菜单栏图标 → **添加显示器...**，命名为 `OPPO_Pad`。
2. 展开 `OPPO_Pad` 子菜单 → **添加分辨率...**。
3. 名称填 `OPPO Pad 3 2800×2000`，宽度 `2800`，高度 `2000`，FPS `60`。
4. 保存后点击这个预设选中。
5. 在 UU 远程里选择 `OPPO_Pad` 显示器，并选择分辨率 **`1400 × 1000 (HiDPI)`**，远程端即可看到 2800×2000 等效画质。

> 默认开启 HiDPI，macOS 内部以 1400×1000 渲染，再放大输出 2800×2000。如果 UU 远程支持 HiDPI 选项，优先选带 HiDPI 标记的逻辑分辨率；不支持时才会直接显示 2800×2000。

### 4K 显示器远程

1. 展开任意显示器子菜单 → **添加分辨率...**。
2. 名称 `4K UHD`，宽度 `3840`，高度 `2160`，FPS `60`。
3. 保存并选中。
4. 远程端选择该显示器后，优先选带 **HiDPI** 的 `1920 × 1080`；如果客户端不支持 HiDPI，则直接选 `3840 × 2160`。

如果远程端字体看起来太小，在远程客户端里调整缩放即可，服务端已经输出完整 4K。

### Mac mini 无头 4K 120Hz

Mac mini 不接显示器时，远程桌面经常只有 1080p。用 VirtualDisplay 可以虚拟一台 4K 高刷屏：

1. 点击菜单栏图标 → **添加显示器...**，命名为 `MacMini_4K`。
2. 展开子菜单 → **添加分辨率...**。
3. 名称 `4K 120Hz`，宽度 `3840`，高度 `2160`，FPS `120`。
4. 保存并选中。
5. 用 VNC / UU 远程 / Screen Sharing 连接，选择 `MacMini_4K`，并优先选带 **HiDPI** 的 `1920 × 1080` 分辨率。

8K 同理，填 `7680 × 4320` 就行。

---

## 菜单里这些是什么意思

- **物理分辨率**：菜单里显示的大数字，也是远程端实际收到的帧缓冲尺寸。比如 `4K UHD 3840×2160`。
- **逻辑分辨率**：括号里的 HiDPI 值，macOS 实际渲染 UI 用的尺寸。VirtualDisplay 固定是物理分辨率的一半，所以 `3840×2160` 对应 `1920×1080 HiDPI`。
- **FPS**：刷新率。自定义预设时可以自己填，不限 60。
- **多分辨率模式**：关闭时只能同时选中一个分辨率；开启时可以同时激活多个，它们都会出现在 macOS 显示器设置里，当前输出的是列表第一个。

  举个例子：一个显示器保存了 `4K UHD` 和 `1080p FHD` 两个预设。
  - 关闭多分辨率模式：菜单里只能勾选一个。你点 `4K UHD` 就输出 4K，再点 `1080p FHD` 就自动切到 1080p。
  - 开启多分辨率模式：两个预设会同时出现在 macOS 的「系统设置 → 显示器」分辨率列表里。你可以直接进系统设置切换；在 VirtualDisplay 菜单里排在第一个的预设是当前实际输出的分辨率。
- **开启/关闭显示器**：临时让某个虚拟显示器上线或下线，状态会记住。删除显示器则是彻底移除配置，最后一台不能删。
- **显示器名称**：只能用字母、数字、下划线。

---

## 什么是 HiDPI，远程时该怎么选

VirtualDisplay 默认创建的虚拟显示器都是 **HiDPI** 模式。

简单来说：

- **物理分辨率**：显示器真实输出的像素数量，也是远程端最终收到的帧缓冲大小。
- **逻辑分辨率**：macOS 渲染 UI 时使用的坐标系大小，只有物理分辨率的一半。
- macOS 先在逻辑分辨率上渲染，再整体放大 2× 输出到物理分辨率，所以 UI 大小正常、文字和图标却很锐利。

举个例子：

| 你添加的预设 | 物理输出 | macOS 内部渲染 | 远程客户端应选 |
|---|---|---|---|
| 4K UHD 3840×2160 | 3840 × 2160 | 1920 × 1080 | **1920 × 1080 HiDPI** |
| OPPO Pad 3 2800×2000 | 2800 × 2000 | 1400 × 1000 | **1400 × 1000 HiDPI** |
| 1080p FHD 1920×1080 | 1920 × 1080 | 960 × 540 | **960 × 540 HiDPI** |

### 远程时怎么选

在 UU 远程、VNC 客户端或 macOS 显示器设置里，你通常会看到两个版本：

1. 带 **HiDPI** 标记的 **逻辑分辨率**（如 `1920 × 1080 HiDPI`）。
2. 不带标记的 **物理分辨率**（如 `3840 × 2160`）。

**优先选带 HiDPI 标记的逻辑分辨率。** 这样 macOS 才会按 2× 渲染，远程端实际拿到的是清晰的 4K 帧缓冲。

如果远程客户端不支持 HiDPI、只列出物理分辨率，那就直接选物理分辨率。此时远程端收到的仍然是 4K 帧缓冲，只是客户端可能按 1:1 显示，导致 UI 偏小，需要在客户端里再调整缩放。

---

## 高刷新率也支持

VirtualDisplay 对 FPS 没有硬性限制，添加分辨率时刷新率可以随便填。只要系统和远程端支持，就能跑出高刷效果。

下图是一台 Mac mini 上创建的虚拟显示器，系统信息里显示为 **2880 × 1800 @ 144Hz**，HiDPI 逻辑分辨率为 **1440 × 900**。

![高刷新率截图](Screenshots/high-refresh.png)

---

## 主要功能

- 支持多个虚拟显示器，每个独立管理分辨率预设。
- 体积小巧，无复杂配置，没有多余后台进程。
- 子菜单分组：预设、多分辨率模式、添加/恢复、开关/重命名/删除。
- 默认以扩展模式加入桌面，不会自动镜像主屏。
- 默认 HiDPI，远程端收到菜单所示的物理分辨率。
- 支持 4K / 8K 等超高分辨率，FPS 不限、可填高刷。
- 在线显示器带 ✓ 高亮，离线显示 `（不可用）`。
- 预设支持添加、编辑、删除、恢复默认。
- 无 Dock，纯菜单栏运行。

---

## 技术实现

- Swift 5 + AppKit + CoreGraphics。
- 核心使用私有 `CGVirtualDisplay` 系列 API。
- 每个显示器用唯一的 `vendorID` / `productID` / `serialNumber` 元组区分，`serialNumber` 只增不复用。
- 配置以 JSON 存在 `UserDefaults` 的 `appConfigurationV2` 里。
- 每次打开菜单时用 `CGGetOnlineDisplayList` 检查显示器是否真正在线。
- 创建显示器后调用 `CGConfigureDisplayMirrorOfDisplay(..., kCGNullDirectDisplay)`，默认非镜像。

---

## 和同类产品对比

| 产品 | 定位 | 多显示器 | 自定义分辨率 | HiDPI | 价格 | 开源 |
|------|------|---------|-------------|-------|------|------|
| **VirtualDisplay** | 轻量菜单栏远程桌面工具 | ✅ 独立管理 | ✅ 自由添加 | ✅ 默认开启 | 免费 | ✅ MIT |
| **BetterDisplay** | 全能显示器管理（DDC、HiDPI、虚拟屏等） | ✅ | ✅ Pro 自定义 | ✅ | 免费基础 / Pro 付费 | ❌ |

VirtualDisplay 不限制 FPS、支持高刷新率，也支持 8K 等超高分辨率，只要系统和远程端能处理。

**VirtualDisplay 适合谁**：

- 只想轻量、快速地给远程端创建几个固定分辨率的虚拟显示器。
- 不想付费、不想配置一堆高级功能。
- 需要多显示器隔离，比如一台 Mac 同时服务多个远程设备。

**暂不支持的功能**：

- 屏幕旋转
- 亮度调节

> 参考来源：[BetterDisplay 功能列表](https://github.com/waydabber/BetterDisplay/wiki/List-of-free-and-Pro-features)、[BetterDisplay 官网](https://betterdisplay.me/)

---

## 从源码构建

```bash
xcodebuild -project VirtualDisplay.xcodeproj -scheme VirtualDisplay -configuration Release build
```

构建产物在 `build/Products/Release/VirtualDisplay.app`。

## License

MIT
