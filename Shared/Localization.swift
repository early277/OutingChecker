import Foundation

enum AppLanguage {
    case japanese
    case english
    case korean

    static var current: AppLanguage {
        let code = Locale.preferredLanguages.first?
            .split(separator: "-")
            .first?
            .lowercased() ?? "ja"

        switch code {
        case "en":
            return .english
        case "ko":
            return .korean
        default:
            return .japanese
        }
    }
}

enum L10n {
    static func text(_ ja: String, _ en: String, _ ko: String) -> String {
        switch AppLanguage.current {
        case .japanese:
            return ja
        case .english:
            return en
        case .korean:
            return ko
        }
    }
}
