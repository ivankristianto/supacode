import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import supacode

@MainActor
struct RepositoriesFeaturePersistenceTests {
  @Test(.dependencies) func taskLoadsPinnedWorktreesBeforeRepositories() async {
    let pinned = ["/tmp/repo/wt-1"]
    let store = TestStore(initialState: RepositoriesFeature.State()) {
      RepositoriesFeature()
    } withDependencies: {
      $0.repositoryPersistence.loadPinnedWorktreeIDs = { pinned }
      $0.repositoryPersistence.loadRoots = { [] }
    }

    await store.send(.task)
    await store.receive(.pinnedWorktreeIDsLoaded(pinned)) {
      $0.pinnedWorktreeIDs = pinned
    }
    await store.receive(.loadPersistedRepositories)
    await store.receive(.repositoriesLoaded([], failures: [], roots: [], animated: false))
    await store.finish()
  }
}
