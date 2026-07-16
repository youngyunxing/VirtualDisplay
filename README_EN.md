<h1 align="center">VirtualDisplay</h1>

<p align="center">
  <strong>Simplified Chinese → <a href="README.md">README.md</a></strong>
</p>

<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://img.shields.io/badge/macOS-13.0%2B-000000?logo=apple" alt="macOS"></a>
  <a href="https://www.swift.org/"><img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License"></a>
  <a href="../../releases/tag/v5.2.0"><img src="https://img.shields.io/badge/Release-v5.2.0-orange.svg" alt="Release"></a>
</p>

VirtualDisplay is a **minimal, lightweight** macOS menu bar tool that creates virtual displays using private CoreGraphics APIs. Built for remote desktop, screen sharing, and headless Macs.

> **The pain point**: when no physical display is connected, macOS only provides a blurry 1080p virtual screen with fuzzy text and a tiny workspace. VirtualDisplay unlocks arbitrary resolutions up to 4K / 8K with HiDPI enabled by default, so remote work still looks crisp.

<p align="center">
  <img src="Screenshots/menu.png" alt="Menu screenshot">
</p>

## Table of Contents

- [Features](#-features)
- [Use Cases](#-use-cases)
- [Requirements](#-requirements)
- [Installation](#-installation)
- [FAQ](#-faq)
- [Usage Examples](#-usage-examples)
- [Menu Guide](#-menu-guide)
- [HiDPI and Resolution Selection](#-hidpi-and-resolution-selection)
- [High Refresh Rate](#-high-refresh-rate)
- [Command Line Tool vdctl](#-command-line-tool-vdctl)
- [Who Is It For](#-who-is-it-for)
- [Building from Source](#-building-from-source)
- [Sponsor](#-sponsor)

## ✨ Features

- **Minimal & lightweight**: runs from the menu bar, no Dock icon, no complex settings panels.
- **Zero configuration**: works out of the box.
- **Arbitrary resolution**: width and height are free-form — 4K, 8K, anything, with no limits.
- **HiDPI support**: clearer picture.
- **High refresh rate**: 60Hz / 120Hz / 144Hz, with no refresh-rate cap and free customization.
- **Multiple isolated displays**: create several virtual displays, each with its own presets.
- **Preset management**: add, edit, delete, restore, and activate resolution presets per display.
- **State persistence**: temporarily turn a display on/off; the state is restored on next launch.
- **CLI friendly**: built-in `vdctl`, JSON output by default, easy to script.
- **Free & open source**: MIT license, no payment or subscription.

## 🎯 Use Cases

- **Remote desktop**: give remote clients (UU Remote, RustDesk, VNC, Screen Sharing, etc.) a fixed-resolution virtual display, so the picture doesn't change with your real screen.
- **With UU Remote**: great for office work, coding, or remotely controlling Claude Code / Codex and other agent setups — even a headless Mac mini gets a full desktop experience.
- **Tablet/phone casting**: let the remote side render at its native resolution, e.g. the OPPO Pad 3's 2800×2000.
- **Multi-device isolation**: create multiple virtual displays, one per remote target, without interference.
- **Mac mini / headless Mac**: when connecting to a Mac mini without a display attached, macOS usually only offers 1080p or lower — blurry picture, tiny workspace. VirtualDisplay can create a 4K, 8K, or any-resolution display, with a refresh rate you choose (60Hz, 120Hz, 144Hz — depending on system and remote client support).

## 💻 Requirements

- macOS 13.0 or later
- Apple Silicon or Intel Mac
- 8GB RAM (16GB recommended for multiple 4K displays)

## 📦 Installation

1. Download `VirtualDisplay.zip` from [Releases](../../releases/latest).
2. Unzip and drag `VirtualDisplay.app` into your Applications folder.
3. Launch it — a display icon appears in the menu bar.<br>"Launch at Login" is enabled automatically on first launch; toggle it in the main menu if needed.
4. Click the menu bar icon → select a preset from the default display, or add a new display / custom resolution.

## ❓ FAQ

### "Cannot Be Opened" or "Is Damaged"

VirtualDisplay is ad-hoc signed and not notarized, so Gatekeeper may block it on the first run. Remove the quarantine flag in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/VirtualDisplay.app
```

Or right-click `VirtualDisplay.app` in Finder → Open, then click Open again in the dialog.

## 🚀 Usage Examples

### OPPO Pad 3 Remote Casting

The OPPO Pad 3 has a 2800×2000 display. To render natively on the remote side:

1. Click the menu bar icon → **Add Display**, name it `OPPO_Pad`.
2. Open the `OPPO_Pad` submenu → **Add Resolution**.
3. Name `OPPO Pad 3`, width `2800`, height `2000`, FPS `60`.
4. Save and click the preset to select it.
5. In UU Remote, select the `OPPO_Pad` display and choose **`1400 × 1000 (HiDPI)`** — the remote side gets 2800×2000-equivalent quality.

> HiDPI is on by default: macOS renders internally at 1400×1000 and outputs 2800×2000 scaled up. If your remote client offers a HiDPI option, prefer the logical resolution marked HiDPI; otherwise it shows 2800×2000 directly.

### 4K Remote

1. Open any display submenu → **Add Resolution**.
2. Name `4K UHD`, width `3840`, height `2160`, FPS `60`.
3. Save and select it.
4. After selecting the display on the remote side, prefer the **HiDPI** `1920 × 1080`; if the client doesn't support HiDPI, choose `3840 × 2160` directly.

### Headless Mac mini 4K 120Hz

A Mac mini without a display often only offers 1080p over remote desktop. With VirtualDisplay you can create a 4K high-refresh display:

1. Click the menu bar icon → **Add Display**, name it `MacMini_4K`.
2. Open the submenu → **Add Resolution**.
3. Name `4K 120Hz`, width `3840`, height `2160`, FPS `120`.
4. Save and select it.
5. Connect via VNC / UU Remote / Screen Sharing, choose `MacMini_4K`, and prefer the **HiDPI** `1920 × 1080` resolution.

Same for 8K — just enter `7680 × 4320`.

## 📖 Menu Guide

- **Physical resolution**: the large numbers in the menu, and the framebuffer size the remote side actually receives. E.g. `4K UHD (3840×2160@60 / 1920×1080 HiDPI)`.
- **Logical resolution**: the HiDPI value in parentheses — the size macOS actually renders the UI at. VirtualDisplay always uses half the physical resolution, so `3840×2160` corresponds to `1920×1080 HiDPI`.
- **FPS**: refresh rate. You can enter any value for custom presets, not just 60.
- **Add Resolution**: the dialog supports choosing from built-in templates (iPad Pro, OPPO Pad 3, MacBook Pro, 4K UHD, 1080p FHD, etc.) or entering width/height/FPS manually.
- **Multi-Resolution Mode**: when off, only one resolution can be selected at a time; when on, multiple presets can be active and all appear in macOS display settings — the first one in the list is the current output, and the VirtualDisplay menu highlights the actual current output preset in green.

  Example: a display has both `4K UHD` and `1080p FHD` presets.
  - Multi-Resolution Mode off: only one can be checked in the menu. Click `4K UHD` for 4K output; click `1080p FHD` to switch to 1080p.
  - Multi-Resolution Mode on: both presets appear in the resolution list in System Settings → Displays. You can switch there directly; in the VirtualDisplay menu, the first preset in the list is the actual current output.
- **Turn display on/off**: temporarily takes a virtual display online or offline; the state is remembered. Deleting a display removes its configuration entirely — the last display can't be deleted.
- **Display name**: letters, digits, and underscores only.

## 🖥️ HiDPI and Resolution Selection

VirtualDisplay creates all virtual displays in **HiDPI** mode by default.

In short:

- **Physical resolution**: the number of pixels the display actually outputs — the framebuffer size the remote side receives.
- **Logical resolution**: the coordinate system macOS uses to render the UI — half the physical resolution.
- macOS renders at the logical resolution first, then scales the whole thing 2× to the physical resolution, so the UI stays normal-sized while text and icons are razor-sharp.

For example:

| Preset you add | Physical output | macOS internal render | Remote client should choose |
|---|---|---|---|
| 4K UHD | 3840 × 2160 | 1920 × 1080 | **1920 × 1080 HiDPI** |
| OPPO Pad 3 | 2800 × 2000 | 1400 × 1000 | **1400 × 1000 HiDPI** |
| 1080p FHD | 1920 × 1080 | 960 × 540 | **960 × 540 HiDPI** |

In UU Remote, VNC clients, or macOS display settings, you'll usually see two variants:

1. The **logical resolution** marked **HiDPI** (e.g. `1920 × 1080 HiDPI`).
2. The **physical resolution** without the mark (e.g. `3840 × 2160`).

**Prefer the HiDPI-marked logical resolution.** That way macOS renders at 2×, and the remote side receives a crisp 4K framebuffer.

If your remote client doesn't support HiDPI and only lists physical resolutions, choose the physical resolution directly. The remote side still receives the 4K framebuffer — it may just display it 1:1, making the UI small; adjust scaling in the client.

## ⚡ High Refresh Rate

VirtualDisplay has no hard FPS limit — enter any refresh rate when adding a resolution. As long as the system and remote client support it, you get high-refresh output.

The screenshot below shows a virtual display created on a Mac mini, reported by System Information as **2880 × 1800 @ 144Hz**, with a HiDPI logical resolution of **1440 × 900**.

![High refresh rate screenshot](Screenshots/high-refresh.png)

## ⌨️ Command Line Tool vdctl

Since v4.0.0, VirtualDisplay ships with the `vdctl` command line tool for scripting and agent automation.

`vdctl` relies on the menu bar app to keep displays alive; if the app isn't running, it automatically launches `/Applications/VirtualDisplay.app`.

```bash
# Show current status
vdctl status

# List displays and presets
vdctl list displays
vdctl list presets VirtualDisplay

# Manage displays
vdctl add display MacMini_4K
vdctl rename display MacMini_4K MacMini_8K
vdctl toggle display MacMini_4K
vdctl remove display MacMini_4K

# Resolution presets
vdctl add preset MacMini_4K "4K 120Hz" 3840 2160 120
vdctl activate preset MacMini_4K "4K 120Hz"
vdctl remove preset MacMini_4K "4K 120Hz"

# Multi-resolution mode
vdctl set multi-resolution MacMini_4K true

# Export / import configuration (v5.0.0+)
vdctl export --path ~/Desktop/vd.json
vdctl export display MacMini_4K --path ~/Desktop/macmini.json
vdctl export preset MacMini_4K "4K 120Hz" --path ~/Desktop/4k120.json
vdctl import --path ~/Desktop/vd.json
vdctl import --path ~/Desktop/vd.json --merge
vdctl import --path ~/Desktop/preset.json --display MacMini_4K

# Export diagnostics (prints to stdout by default, --path writes a file)
vdctl diagnostics
vdctl diagnostics --path ~/Desktop/diag.txt
```

### Import / Export Configuration

Since v5.0.0, configurations can be exported and imported as JSON:

- **Export**:
  - Below "Import Configuration" in the main menu, each display submenu has "Export Display Configuration".
  - Each preset submenu has "Export".
  - `vdctl export` supports full / display / preset scopes.
  - Exported JSON strips hardware identifiers (`vendorID` / `productID` / `serialNumber`) for safe sharing.
- **Import**: "Import Configuration" in the menu, or `vdctl import --path`.
  - **Replace** is the default — a confirmation dialog is shown for menu imports.
  - Use `--merge` to merge into the current configuration; name conflicts get an `_imported` suffix automatically.
  - All display/preset IDs and hardware identifiers are regenerated on import to avoid conflicts.

Exported JSON can be sent to anyone directly — they just use "Import Configuration" to restore it.

Example exported JSON:

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

All commands output JSON by default, write errors to stderr, and exit non-zero on failure. After installation, `vdctl` lives at `/Applications/VirtualDisplay.app/Contents/MacOS/vdctl` and can be linked into your PATH:

```bash
ln -s /Applications/VirtualDisplay.app/Contents/MacOS/vdctl /usr/local/bin/vdctl
```

## 🎯 Who Is It For

VirtualDisplay has no FPS limit, supports high refresh rates, and supports ultra-high resolutions like 8K — as long as the system and remote client can handle it.

**VirtualDisplay is for you if**:

- You just want a lightweight, quick way to create a few fixed-resolution virtual displays for remote access.
- You don't want to pay or configure a pile of advanced features.
- You need multiple isolated displays — e.g. one Mac serving several remote devices.

**Not currently supported**:

- Display rotation
- Brightness control

If you only need one fixed resolution and don't want to install software, a cheap HDMI dummy plug is also an option, but it doesn't provide HiDPI or multi-display isolation.

## 🛠️ Building from Source

```bash
rm -rf build
xcodebuild build -project VirtualDisplay.xcodeproj -scheme VirtualDisplay -configuration Release -derivedDataPath build CONFIGURATION_BUILD_DIR=build/Release
```

The build product is at `build/Release/VirtualDisplay.app`, with `vdctl` bundled into `VirtualDisplay.app/Contents/MacOS/vdctl`. You can also build the CLI alone:

```bash
xcodebuild build -project VirtualDisplay.xcodeproj -scheme vdctl -configuration Release -derivedDataPath build CONFIGURATION_BUILD_DIR=build/Release
```

## ☕ Sponsor

If VirtualDisplay helps you, buy me a Mixue to support ongoing maintenance:

<p align="center">
  <img src="VirtualDisplay/Resources/donate-qr.png" alt="Sponsor (WeChat QR code)" width="220"><br>
  <sub>Scan with WeChat to sponsor</sub>
</p>

