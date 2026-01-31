import ComposableArchitecture
import Foundation

@Reducer
struct RepositorySettingsFeature {
  @ObservableState
  struct State: Equatable {
    var rootURL: URL
    var settings: RepositorySettings
    var isBareRepository = false
  }

  enum Action: Equatable {
    case task
    case settingsLoaded(RepositorySettings, isBareRepository: Bool)
    case setSetupScript(String)
    case setRunScript(String)
    case setCopyIgnoredOnWorktreeCreate(Bool)
    case setCopyUntrackedOnWorktreeCreate(Bool)
    case delegate(Delegate)
  }

  enum Delegate: Equatable {
    case settingsChanged(URL)
  }

  @Dependency(\.repositorySettingsClient) private var repositorySettingsClient
  @Dependency(\.gitClient) private var gitClient

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        let gitClient = gitClient
        return .run { send in
          let settings = repositorySettingsClient.load(rootURL)
          let isBareRepository = (try? await gitClient.isBareRepository(rootURL)) ?? false
          await send(.settingsLoaded(settings, isBareRepository: isBareRepository))
        }

      case .settingsLoaded(let settings, let isBareRepository):
        state.settings = settings
        state.isBareRepository = isBareRepository
        return .none

      case .setSetupScript(let script):
        state.settings.setupScript = script
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .setRunScript(let script):
        state.settings.runScript = script
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .setCopyIgnoredOnWorktreeCreate(let isEnabled):
        state.settings.copyIgnoredOnWorktreeCreate = isEnabled
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .setCopyUntrackedOnWorktreeCreate(let isEnabled):
        state.settings.copyUntrackedOnWorktreeCreate = isEnabled
        let settings = state.settings
        let rootURL = state.rootURL
        let repositorySettingsClient = repositorySettingsClient
        return .run { send in
          repositorySettingsClient.save(settings, rootURL)
          await send(.delegate(.settingsChanged(rootURL)))
        }

      case .delegate:
        return .none
      }
    }
  }
}
