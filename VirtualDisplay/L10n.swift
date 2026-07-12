import Foundation

/// 极简双语助手：系统首选语言为英文时返回英文，否则返回中文（默认中文）。
/// 不用 String Catalog 的原因：vdctl 是命令行 target，无法嵌入 .xcstrings 资源，
/// 而它与 App 共享 DisplayEngine / ConfigurationExchange 等代码，手工双语在两侧行为一致。
enum L10n {
    static var isEnglish: Bool {
        Locale.preferredLanguages.first?.hasPrefix("en") == true
    }

    static func pick(_ zh: String, _ en: String) -> String {
        isEnglish ? en : zh
    }
}
