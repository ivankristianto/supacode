import ComposableArchitecture
import Sharing

struct SettingsClient {
  var load: @Sendable () async -> GlobalSettings
  var save: @Sendable (GlobalSettings) async -> Void
}

extension SettingsClient: DependencyKey {
  static let liveValue = SettingsClient(
    load: {
      @Shared(.settingsFile) var settings: SettingsFile
      return settings.global
    },
    save: { settings in
      @Shared(.settingsFile) var fileSettings: SettingsFile
      $fileSettings.withLock {
        $0.global = settings
      }
    }
  )
  static let testValue = SettingsClient(
    load: { .default },
    save: { _ in }
  )
}

extension DependencyValues {
  var settingsClient: SettingsClient {
    get { self[SettingsClient.self] }
    set { self[SettingsClient.self] = newValue }
  }
}
