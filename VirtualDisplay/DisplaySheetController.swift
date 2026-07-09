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
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

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
                errorMessage = "显示器名称不能为空，且只能包含字母、数字和下划线。"
            } else if !DisplayEngine.isDisplayNameUnique(name, in: store.configuration.displays, excluding: excludingDisplayID) {
                errorMessage = "已存在名为「\(name)」的显示器，请使用其他名称。"
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
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 240))

        let titleLabel = NSTextField(labelWithString: preset == nil ? "添加分辨率" : "编辑分辨率")
        titleLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        titleLabel.alignment = .center

        let descLabel = NSTextField(labelWithString: "输入分辨率名称、宽度、高度和刷新率（FPS）。")
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
            popup.addItem(withTitle: "自定义")
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
            formRows.append(makePopupRow(label: "模板:", popup: popup))
        }

        formRows.append(contentsOf: [
            makeRow(label: "名称:", field: nameField),
            makeRow(label: "宽度:", field: widthField),
            makeRow(label: "高度:", field: heightField),
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
                errorMessage = "名称不能为空。"
            } else if display.presets.contains(where: { $0.name == name && $0.id != preset?.id }) {
                errorMessage = "该显示器下已存在名为「\(name)」的预设。"
            } else if widthString.isEmpty || heightString.isEmpty || fpsString.isEmpty {
                errorMessage = "宽度、高度、刷新率均不能为空。"
            } else if Int(widthString) == nil || Int(heightString) == nil || Int(fpsString) == nil {
                errorMessage = "宽度、高度、刷新率必须为正整数（仅支持数字）。"
            } else if let width = Int(widthString), let height = Int(heightString), let fps = Int(fpsString) {
                if width <= 0 || height <= 0 || fps <= 0 {
                    errorMessage = "宽度、高度、刷新率必须大于 0。"
                } else if width % 2 != 0 || height % 2 != 0 {
                    errorMessage = "HiDPI 模式下宽度和高度必须为偶数。"
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
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        completion(alert.runModal() == .alertFirstButtonReturn)
    }

    func showRestorableAlert(title: String, informativeText: String, message: String, completion: (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = informativeText
        alert.alertStyle = .informational
        alert.addButton(withTitle: "恢复")
        alert.addButton(withTitle: "取消")

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
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    func showAboutPanel(
        version: String,
        onCheckForUpdates: @escaping () -> Void,
        onDonate: @escaping () -> Void,
        onFeedback: @escaping () -> Void,
        onStar: @escaping () -> Void
    ) {
        final class AboutActionHandler: NSObject {
            let onCheckForUpdates: () -> Void
            let onDonate: () -> Void
            let onFeedback: () -> Void
            let onStar: () -> Void

            init(
                onCheckForUpdates: @escaping () -> Void,
                onDonate: @escaping () -> Void,
                onFeedback: @escaping () -> Void,
                onStar: @escaping () -> Void
            ) {
                self.onCheckForUpdates = onCheckForUpdates
                self.onDonate = onDonate
                self.onFeedback = onFeedback
                self.onStar = onStar
                super.init()
            }

            @objc func checkForUpdates() { onCheckForUpdates() }
            @objc func donate() { onDonate() }
            @objc func feedback() { onFeedback() }
            @objc func star() { onStar() }
        }

        let handler = AboutActionHandler(
            onCheckForUpdates: onCheckForUpdates,
            onDonate: onDonate,
            onFeedback: onFeedback,
            onStar: onStar
        )
        self.presetTemplateHandler = handler

        let alert = NSAlert()
        alert.messageText = "VirtualDisplay"
        alert.informativeText = "轻量级 macOS 虚拟显示器工具"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "关闭")

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 82))

        let versionLabel = NSTextField(labelWithString: "版本 \(version)")
        versionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center

        let copyrightLabel = NSTextField(labelWithString: "MIT License · youngyunxing")
        copyrightLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        copyrightLabel.textColor = .secondaryLabelColor
        copyrightLabel.alignment = .center

        func makeButton(title: String, action: Selector) -> NSButton {
            let button = NSButton(title: title, target: handler, action: action)
            button.bezelStyle = .rounded
            button.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            button.controlSize = .regular
            button.heightAnchor.constraint(equalToConstant: 28).isActive = true
            return button
        }

        let buttonStack = NSStackView(views: [
            NSStackView(views: [
                makeButton(title: "检查更新", action: #selector(AboutActionHandler.checkForUpdates)),
                makeButton(title: "打赏开发者", action: #selector(AboutActionHandler.donate))
            ]),
            NSStackView(views: [
                makeButton(title: "反馈建议", action: #selector(AboutActionHandler.feedback)),
                makeButton(title: "GitHub Star", action: #selector(AboutActionHandler.star))
            ])
        ])
        buttonStack.orientation = .vertical
        buttonStack.alignment = .centerX
        buttonStack.spacing = 8
        buttonStack.arrangedSubviews.forEach { row in
            guard let rowStack = row as? NSStackView else { return }
            rowStack.orientation = .horizontal
            rowStack.alignment = .centerY
            rowStack.spacing = 10
            rowStack.distribution = .fillEqually
        }

        let textStack = NSStackView(views: [versionLabel, copyrightLabel])
        textStack.orientation = .vertical
        textStack.alignment = .centerX
        textStack.spacing = 0

        let stack = NSStackView(views: [textStack, buttonStack])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])

        alert.accessoryView = container
        alert.runModal()
    }

    func showUpToDate(version: String) {
        let alert = NSAlert()
        alert.messageText = "当前已是最新版本"
        alert.informativeText = "版本 \(version)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    func showUpdateAvailable(localVersion: String, remoteVersion: String, htmlURL: URL) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 v\(remoteVersion)"
        alert.informativeText = "当前版本：v\(localVersion)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "去下载")
        alert.addButton(withTitle: "忽略")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(htmlURL)
        }
    }

    func showDonationURLMissing() {
        let alert = NSAlert()
        alert.messageText = "打赏链接暂未配置"
        alert.informativeText = "请在 Info.plist 中设置 VDDonationURL。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}
