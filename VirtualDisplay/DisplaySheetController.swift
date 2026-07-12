import Cocoa
import UniformTypeIdentifiers

final class DisplaySheetController {
    private let store: ConfigurationStore
    private var presetTemplateHandler: AnyObject?

    init(store: ConfigurationStore) {
        self.store = store
    }

    func showDisplayNameEditor(
        title: String,
        description: String,
        defaultName: String,
        excludingDisplayID: String? = nil,
        completion: @escaping (String?) -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = ""
        alert.informativeText = ""
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.pick("保存", "Save"))
        alert.addButton(withTitle: L10n.pick("取消", "Cancel"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 110))

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.alignment = .center

        let descLabel = NSTextField(labelWithString: description)
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.preferredMaxLayoutWidth = 240

        let nameField = NSTextField()
        nameField.stringValue = defaultName
        nameField.placeholderString = "VirtualDisplay_1"
        nameField.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.preferredMaxLayoutWidth = 240
        errorLabel.usesSingleLineMode = false
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.cell?.wraps = true
        errorLabel.cell?.isScrollable = false
        errorLabel.isHidden = true

        let stack = NSStackView(views: [titleLabel, descLabel, nameField, errorLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        alert.accessoryView = container
        alert.window.initialFirstResponder = nameField

        while true {
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                completion(nil)
                return
            }

            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            var errorMessage: String?
            if !DisplayEngine.isValidDisplayName(name) {
                errorMessage = L10n.pick("显示器名称不能为空，且只能包含字母、数字和下划线。", "Display name cannot be empty and may only contain letters, digits, and underscores.")
            } else if !DisplayEngine.isDisplayNameUnique(name, in: store.configuration.displays, excluding: excludingDisplayID) {
                errorMessage = L10n.pick("已存在名为「\(name)」的显示器，请使用其他名称。", "A display named \"\(name)\" already exists. Please choose another name.")
            }

            if let message = errorMessage {
                errorLabel.stringValue = message
                errorLabel.isHidden = false
                continue
            }

            completion(name)
            return
        }
    }

    func showPresetEditor(displayID: String, preset: DisplayPreset?, completion: @escaping (DisplayPreset?) -> Void) {
        guard let display = store.configuration.displays.first(where: { $0.id == displayID }) else {
            completion(nil)
            return
        }

        let alert = NSAlert()
        alert.messageText = ""
        alert.informativeText = ""
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.pick("保存", "Save"))
        alert.addButton(withTitle: L10n.pick("取消", "Cancel"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 240))

        let titleLabel = NSTextField(labelWithString: preset == nil ? L10n.pick("添加分辨率", "Add Resolution") : L10n.pick("编辑分辨率", "Edit Resolution"))
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.alignment = .center

        let descLabel = NSTextField(labelWithString: L10n.pick("输入分辨率名称、宽度、高度和刷新率（FPS）。", "Enter the resolution name, width, height, and refresh rate (FPS)."))
        descLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        descLabel.textColor = .secondaryLabelColor
        descLabel.alignment = .center
        descLabel.preferredMaxLayoutWidth = 240

        let nameField = NSTextField()
        nameField.placeholderString = "4K UHD"
        nameField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let widthField = NSTextField()
        widthField.placeholderString = "3840"
        widthField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let heightField = NSTextField()
        heightField.placeholderString = "2160"
        heightField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let fpsField = NSTextField()
        fpsField.placeholderString = "60"
        fpsField.widthAnchor.constraint(equalToConstant: 180).isActive = true

        let errorLabel = NSTextField(labelWithString: "")
        errorLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        errorLabel.textColor = .systemRed
        errorLabel.alignment = .center
        errorLabel.preferredMaxLayoutWidth = 240
        errorLabel.usesSingleLineMode = false
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.cell?.wraps = true
        errorLabel.cell?.isScrollable = false
        errorLabel.isHidden = true

        func makeRow(label: String, field: NSTextField) -> NSStackView {
            let labelView = NSTextField(labelWithString: label)
            labelView.alignment = .right
            labelView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            labelView.widthAnchor.constraint(equalToConstant: 50).isActive = true

            let row = NSStackView(views: [labelView, field])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.distribution = .fill
            return row
        }

        func makePopupRow(label: String, popup: NSPopUpButton) -> NSStackView {
            let labelView = NSTextField(labelWithString: label)
            labelView.alignment = .right
            labelView.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            labelView.widthAnchor.constraint(equalToConstant: 50).isActive = true

            let row = NSStackView(views: [labelView, popup])
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.distribution = .fill
            return row
        }

        let templates = DisplayTemplateLoader.load()
        var formRows: [NSView] = []

        if preset == nil && !templates.isEmpty {
            final class TemplateHandler: NSObject {
                let templates: [DisplayTemplate]
                weak var nameField: NSTextField?
                weak var widthField: NSTextField?
                weak var heightField: NSTextField?
                weak var fpsField: NSTextField?

                init(templates: [DisplayTemplate], nameField: NSTextField, widthField: NSTextField, heightField: NSTextField, fpsField: NSTextField) {
                    self.templates = templates
                    self.nameField = nameField
                    self.widthField = widthField
                    self.heightField = heightField
                    self.fpsField = fpsField
                }

                @objc func selected(_ sender: NSPopUpButton) {
                    let index = sender.indexOfSelectedItem
                    guard index > 0 else { return }
                    let template = templates[index - 1]
                    nameField?.stringValue = template.name
                    widthField?.stringValue = String(template.width)
                    heightField?.stringValue = String(template.height)
                    fpsField?.stringValue = String(template.refreshRate)
                }
            }

            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.addItem(withTitle: L10n.pick("自定义", "Custom"))
            for template in templates {
                popup.addItem(withTitle: template.name)
            }
            popup.isEnabled = true
            popup.menu?.autoenablesItems = false
            popup.itemArray.forEach { $0.isEnabled = true }
            popup.widthAnchor.constraint(equalToConstant: 180).isActive = true

            let handler = TemplateHandler(templates: templates, nameField: nameField, widthField: widthField, heightField: heightField, fpsField: fpsField)
            popup.target = handler
            popup.action = #selector(TemplateHandler.selected(_:))
            self.presetTemplateHandler = handler
            formRows.append(makePopupRow(label: L10n.pick("模板:", "Template:"), popup: popup))
        }

        formRows.append(contentsOf: [
            makeRow(label: L10n.pick("名称:", "Name:"), field: nameField),
            makeRow(label: L10n.pick("宽度:", "Width:"), field: widthField),
            makeRow(label: L10n.pick("高度:", "Height:"), field: heightField),
            makeRow(label: "FPS:", field: fpsField)
        ])

        let formStack = NSStackView(views: formRows)
        formStack.orientation = .vertical
        formStack.alignment = .centerX
        formStack.spacing = 6

        let stack = NSStackView(views: [titleLabel, descLabel, formStack, errorLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])

        if let preset = preset {
            nameField.stringValue = preset.name
            widthField.stringValue = String(preset.width)
            heightField.stringValue = String(preset.height)
            fpsField.stringValue = String(preset.refreshRate)
        } else {
            nameField.stringValue = ""
            widthField.stringValue = ""
            heightField.stringValue = ""
            fpsField.stringValue = "60"
        }

        alert.accessoryView = container
        alert.window.initialFirstResponder = nameField

        while true {
            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else {
                completion(nil)
                return
            }

            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let widthString = widthField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let heightString = heightField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let fpsString = fpsField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

            var errorMessage: String?
            if name.isEmpty {
                errorMessage = L10n.pick("名称不能为空。", "Name cannot be empty.")
            } else if display.presets.contains(where: { $0.name == name && $0.id != preset?.id }) {
                errorMessage = L10n.pick("该显示器下已存在名为「\(name)」的预设。", "A preset named \"\(name)\" already exists for this display.")
            } else if widthString.isEmpty || heightString.isEmpty || fpsString.isEmpty {
                errorMessage = L10n.pick("宽度、高度、刷新率均不能为空。", "Width, height, and refresh rate cannot be empty.")
            } else if Int(widthString) == nil || Int(heightString) == nil || Int(fpsString) == nil {
                errorMessage = L10n.pick("宽度、高度、刷新率必须为正整数（仅支持数字）。", "Width, height, and refresh rate must be positive integers (digits only).")
            } else if let width = Int(widthString), let height = Int(heightString), let fps = Int(fpsString) {
                if width <= 0 || height <= 0 || fps <= 0 {
                    errorMessage = L10n.pick("宽度、高度、刷新率必须大于 0。", "Width, height, and refresh rate must be greater than 0.")
                } else if width % 2 != 0 || height % 2 != 0 {
                    errorMessage = L10n.pick("HiDPI 模式下宽度和高度必须为偶数。", "Width and height must be even numbers in HiDPI mode.")
                }
            }

            if let message = errorMessage {
                errorLabel.stringValue = message
                errorLabel.isHidden = false
                continue
            }

            let id = preset?.id ?? UUID().uuidString
            let updated = DisplayPreset(
                id: id,
                name: name,
                width: Int(widthString)!,
                height: Int(heightString)!,
                refreshRate: Int(fpsString)!,
                vendorID: 0x0001,
                productID: 0x0001
            )
            completion(updated)
            return
        }
    }

    func showConfirmation(title: String, message: String, style: NSAlert.Style = .warning, completion: (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: L10n.pick("确定", "OK"))
        alert.addButton(withTitle: L10n.pick("取消", "Cancel"))
        completion(alert.runModal() == .alertFirstButtonReturn)
    }

    func showRestorableAlert(title: String, informativeText: String, message: String, completion: (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.pick("恢复", "Restore"))
        alert.addButton(withTitle: L10n.pick("取消", "Cancel"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 60))

        let messageLabel = NSTextField(frame: NSRect(x: 40, y: 0, width: 240, height: 60))
        messageLabel.stringValue = message
        messageLabel.alignment = .center
        messageLabel.isEditable = false
        messageLabel.isBordered = false
        messageLabel.backgroundColor = .clear
        messageLabel.usesSingleLineMode = false
        messageLabel.cell?.wraps = true
        messageLabel.cell?.isScrollable = false
        messageLabel.lineBreakMode = .byWordWrapping
        container.addSubview(messageLabel)

        alert.accessoryView = container

        completion(alert.runModal() == .alertFirstButtonReturn)
    }

    func showOpenPanel(allowedContentTypes: [UTType] = [.json], completion: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = allowedContentTypes
        panel.runModal()
        completion(panel.url)
    }

    func showSavePanel(defaultName: String, completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        panel.allowedContentTypes = [.json]
        panel.runModal()
        completion(panel.url)
    }

    func copyStringToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: L10n.pick("确定", "OK"))
        alert.runModal()
    }

    func showSponsorQR() {
        let alert = NSAlert()
        alert.messageText = L10n.pick("赞助支持", "Sponsor")
        alert.informativeText = L10n.pick("感谢你对 VirtualDisplay 的支持 ❤️", "Thank you for supporting VirtualDisplay ❤️")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.pick("关闭", "Close"))

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 300))

        let qrImageView = NSImageView()
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.widthAnchor.constraint(equalToConstant: 240).isActive = true
        qrImageView.heightAnchor.constraint(equalToConstant: 240).isActive = true
        if let qrURL = Bundle.main.url(forResource: "donate-qr", withExtension: "png"),
           let qrImage = NSImage(contentsOf: qrURL) {
            qrImageView.image = qrImage
        } else {
            qrImageView.image = NSImage(size: NSSize(width: 240, height: 240))
        }

        let qrHintLabel = NSTextField(labelWithString: L10n.pick("请我喝蜜雪", "Buy me a Mixue 🧋"))
        qrHintLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        qrHintLabel.textColor = .secondaryLabelColor
        qrHintLabel.alignment = .center
        qrHintLabel.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let stack = NSStackView(views: [qrImageView, qrHintLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8)
        ])

        alert.accessoryView = container
        alert.runModal()
    }

    func showUpToDate(version: String) {
        let alert = NSAlert()
        alert.messageText = L10n.pick("当前已是最新版本", "You're Up to Date")
        alert.informativeText = L10n.pick("版本 \(version)", "Version \(version)")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.pick("确定", "OK"))
        alert.runModal()
    }

    func showUpdateAvailable(localVersion: String, remoteVersion: String, htmlURL: URL) {
        let alert = NSAlert()
        alert.messageText = L10n.pick("发现新版本 v\(remoteVersion)", "New Version Available: v\(remoteVersion)")
        alert.informativeText = L10n.pick("当前版本：v\(localVersion)", "Current version: v\(localVersion)")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.pick("去下载", "Download"))
        alert.addButton(withTitle: L10n.pick("忽略", "Ignore"))
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(htmlURL)
        }
    }
}
