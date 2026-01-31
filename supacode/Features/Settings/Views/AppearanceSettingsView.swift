import ComposableArchitecture
import SwiftUI

struct AppearanceSettingsView: View {
  @Bindable var store: StoreOf<SettingsFeature>

  var body: some View {
    VStack(alignment: .leading) {
      Form {
        Section("Appearance") {
          HStack {
            ForEach(AppearanceMode.allCases) { mode in
              AppearanceOptionCardView(
                mode: mode,
                isSelected: mode == store.appearanceMode
              ) {
                store.send(.setAppearanceMode(mode))
              }
            }
          }
        }
        Section("Quit") {
          Toggle(
            "Confirm before quitting",
            isOn: Binding(
              get: { store.confirmBeforeQuit },
              set: { store.send(.setConfirmBeforeQuit($0)) }
            )
          )
          .help("Ask before quitting Supacode")
        }
      }
      .formStyle(.grouped)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
