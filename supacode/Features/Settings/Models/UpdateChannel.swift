import Foundation

enum UpdateChannel: String, Codable, CaseIterable, Sendable {
  case stable
  case tip

  var feedURL: URL {
    switch self {
    case .stable:
      URL(string: "https://supacode.sh/download/latest/appcast.xml")!
    case .tip:
      URL(string: "https://supacode.sh/download/tip/appcast.xml")!
    }
  }
}
