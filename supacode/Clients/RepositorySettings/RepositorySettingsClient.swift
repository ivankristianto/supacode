import ComposableArchitecture
import Foundation
import Sharing

struct RepositorySettingsClient {
  var load: @Sendable (URL) -> RepositorySettings
  var save: @Sendable (_ settings: RepositorySettings, _ rootURL: URL) -> Void
}

extension RepositorySettingsClient: DependencyKey {
  static let liveValue = RepositorySettingsClient(
    load: { rootURL in
      @Shared(.repositorySettings(rootURL)) var settings: RepositorySettings
      return settings
    },
    save: { settings, rootURL in
      @Shared(.repositorySettings(rootURL)) var sharedSettings: RepositorySettings
      $sharedSettings.withLock {
        $0 = settings
      }
    }
  )
  static let testValue = RepositorySettingsClient(
    load: { _ in .default },
    save: { _, _ in }
  )
}

extension DependencyValues {
  var repositorySettingsClient: RepositorySettingsClient {
    get { self[RepositorySettingsClient.self] }
    set { self[RepositorySettingsClient.self] = newValue }
  }
}
