import Foundation

struct UpdateInfo {
    let version: String
    let htmlURL: URL
    let isNewerThanLocal: Bool
}

final class UpdateChecker {
    static let shared = UpdateChecker()

    private let releasesURL = URL(string: "https://api.github.com/repos/youngyunxing/VirtualDisplay/releases/latest")!
    private let localVersion: String

    init(localVersion: String? = nil) {
        self.localVersion = localVersion ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    func checkForUpdates(completion: @escaping (Result<UpdateInfo, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: releasesURL) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String,
                  let htmlURLString = json["html_url"] as? String,
                  let htmlURL = URL(string: htmlURLString) else {
                DispatchQueue.main.async { completion(.failure(UpdateCheckError.invalidResponse)) }
                return
            }

            let remoteVersion = self.stripVersionPrefix(tagName)
            let isNewer = self.compareVersions(remoteVersion, self.localVersion) == .orderedDescending

            DispatchQueue.main.async {
                completion(.success(UpdateInfo(version: remoteVersion, htmlURL: htmlURL, isNewerThanLocal: isNewer)))
            }
        }
        task.resume()
    }

    private func stripVersionPrefix(_ version: String) -> String {
        version.hasPrefix("v") || version.hasPrefix("V") ? String(version.dropFirst()) : version
    }

    private func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        let maxLength = max(left.count, right.count)
        for i in 0..<maxLength {
            let l = i < left.count ? left[i] : 0
            let r = i < right.count ? right[i] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}

enum UpdateCheckError: Error {
    case invalidResponse
}
