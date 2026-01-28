import ComposableArchitecture
import DependenciesTestSupport
import Testing

@testable import supacode

@MainActor
struct SettingsFeatureTests {
  @Test(.dependencies) func loadSettings() async {
    let loaded = GlobalSettings(
      appearanceMode: .dark,
      updatesAutomaticallyCheckForUpdates: false,
      updatesAutomaticallyDownloadUpdates: true,
      inAppNotificationsEnabled: false,
      notificationSoundEnabled: true
    )
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.settingsClient.load = { loaded }
    }

    await store.send(.task)
    await store.receive(.settingsLoaded(loaded)) {
      $0.appearanceMode = .dark
      $0.updatesAutomaticallyCheckForUpdates = false
      $0.updatesAutomaticallyDownloadUpdates = true
      $0.inAppNotificationsEnabled = false
      $0.notificationSoundEnabled = true
    }
    await store.receive(.delegate(.settingsChanged(loaded)))
  }

  @Test(.dependencies) func savesUpdatesChanges() async {
    let saved = LockIsolated<GlobalSettings?>(nil)
    let store = TestStore(initialState: SettingsFeature.State()) {
      SettingsFeature()
    } withDependencies: {
      $0.settingsClient.save = { settings in
        saved.withValue { $0 = settings }
      }
    }

    await store.send(.setAppearanceMode(.light)) {
      $0.appearanceMode = .light
    }
    let expectedSettings = GlobalSettings(
      appearanceMode: .light,
      updatesAutomaticallyCheckForUpdates: true,
      updatesAutomaticallyDownloadUpdates: false,
      inAppNotificationsEnabled: true,
      notificationSoundEnabled: true
    )
    await store.receive(.delegate(.settingsChanged(expectedSettings)))

    await store.finish()
    #expect(saved.value == expectedSettings)
  }
}
