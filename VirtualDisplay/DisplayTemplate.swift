import Foundation

struct DisplayTemplate: Codable {
    let name: String
    let width: Int
    let height: Int
    let refreshRate: Int
}

enum DisplayTemplateLoader {
    static func load() -> [DisplayTemplate] {
        guard let url = Bundle.main.url(forResource: "display-templates", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([DisplayTemplate].self, from: data)) ?? []
    }
}
