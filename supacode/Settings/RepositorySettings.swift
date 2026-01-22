import Foundation

nonisolated struct RepositorySettings: Codable, Equatable {
  var startupCommand: String
  var openActionID: String

  private enum CodingKeys: String, CodingKey {
    case startupCommand
    case openActionID
  }

  static let `default` = RepositorySettings(
    startupCommand: "echo 123",
    openActionID: "finder"
  )

  init(startupCommand: String, openActionID: String) {
    self.startupCommand = startupCommand
    self.openActionID = openActionID
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    startupCommand = try container.decodeIfPresent(String.self, forKey: .startupCommand)
      ?? Self.default.startupCommand
    openActionID = try container.decodeIfPresent(String.self, forKey: .openActionID)
      ?? Self.default.openActionID
  }
}
