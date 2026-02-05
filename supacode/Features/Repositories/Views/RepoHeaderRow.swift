import SwiftUI

struct RepoHeaderRow: View {
  let name: String
  let isRemoving: Bool
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let nameColor = colorScheme == .dark ? Color.white : Color.primary
    HStack {
      Text(name)
        .foregroundStyle(nameColor)
      if isRemoving {
        Text("Removing...")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
  }
}
