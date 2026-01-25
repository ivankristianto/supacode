import SwiftUI

struct CodingAgentSettingsView: View {
  var body: some View {
    VStack(alignment: .leading) {
      Form {
        Section {
          Text("No settings yet.")
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}
