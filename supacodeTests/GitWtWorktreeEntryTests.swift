import Foundation
import Testing

@testable import supacode

struct GitWtWorktreeEntryTests {
  @Test func decodesIsBare() throws {
    let json = """
      [
        {"branch":"(bare)","path":"/tmp/repo.git","head":"","is_bare":true},
        {"branch":"main","path":"/tmp/worktree","head":"abc123","is_bare":false}
      ]
      """
    let data = Data(json.utf8)
    let entries = try JSONDecoder().decode([GitWtWorktreeEntry].self, from: data)
    #expect(entries.count == 2)
    #expect(entries[0].isBare)
    #expect(entries[1].isBare == false)
  }

  @Test func filtersBareEntries() {
    let entries = [
      GitWtWorktreeEntry(branch: "(bare)", path: "/tmp/repo.git", head: "", isBare: true),
      GitWtWorktreeEntry(branch: "main", path: "/tmp/worktree", head: "abc123", isBare: false),
    ]
    let filtered = entries.filter { !$0.isBare }
    #expect(filtered.count == 1)
    #expect(filtered.first?.branch == "main")
  }

  @Test func extractJSONFromCleanOutput() {
    let output = #"[{"branch":"main","path":"/tmp"}]"#
    let extracted = GitClient.extractJSON(from: output)
    #expect(extracted == output)
  }

  @Test func extractJSONWithShellPollution() {
    let output = """
      ls='ls -G'
      [{"branch":"main","path":"/tmp"}]
      """
    let extracted = GitClient.extractJSON(from: output)
    #expect(extracted == #"[{"branch":"main","path":"/tmp"}]"#)
  }

  @Test func extractJSONWithMultipleLines() {
    let output = """
      some output
      more output
      [{"branch":"main"}]
      trailing text
      """
    let extracted = GitClient.extractJSON(from: output)
    #expect(extracted == #"[{"branch":"main"}]"#)
  }

  @Test func extractJSONReturnsOriginalWhenNoJSON() {
    let output = "no json here"
    let extracted = GitClient.extractJSON(from: output)
    #expect(extracted == output)
  }
}
