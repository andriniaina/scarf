import Foundation
import Testing
import ScarfDesign
@testable import scarf

/// The Kanban inspector used to render a card's body and comments as plain
/// `Text`, on the theory that worker-authored content must never reach a
/// markdown renderer. The real constraint was narrower: it must never reach
/// a renderer with no link-scheme allowlist. `MarkdownContentView` carries
/// that allowlist, so both now render through it.
///
/// These tests pin the three things that made that swap legitimate, and the
/// one place it is deliberately NOT done (iOS).
@Suite("Kanban body + comments render as markdown")
struct KanbanMarkdownBodyTests {

    private static var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // …/scarfTests
            .deletingLastPathComponent()   // …/scarf
    }

    private static func source(_ relative: String) throws -> String {
        try String(
            contentsOf: root.appendingPathComponent(relative),
            encoding: .utf8
        )
    }

    // MARK: - 1. Routing pin

    /// The inspector must route both text surfaces through
    /// `MarkdownContentView` — and must not have a bare `Text(...)` of the
    /// same content alongside it, which would mean one of the two silently
    /// went back to plain text.
    @Test("the inspector renders body and comments through MarkdownContentView")
    func theInspectorRoutesThroughTheSafeRenderer() throws {
        let src = try Self.source("scarf/Features/Kanban/Views/KanbanInspectorPane.swift")

        #expect(
            src.contains("MarkdownContentView(content: body)"),
            "the task body is no longer rendered as markdown"
        )
        #expect(
            src.contains("MarkdownContentView(content: comment.body)"),
            "comments are no longer rendered as markdown"
        )
        #expect(
            !src.contains("Text(body)\n"),
            "a bare Text(body) survives alongside the markdown renderer"
        )
        #expect(
            !src.contains("Text(comment.body)\n"),
            "a bare Text(comment.body) survives alongside the markdown renderer"
        )
    }

    /// Adjacent comments are separated by a hairline, and only adjacent
    /// ones: a divider above the first or below the last would frame the
    /// list instead of separating its items.
    @Test("comments are separated by a conditional divider")
    func commentsAreSeparatedByADivider() throws {
        let src = try Self.source("scarf/Features/Kanban/Views/KanbanInspectorPane.swift")

        #expect(
            src.contains("if index > 0 {\n                        ScarfDivider()"),
            "the comment list lost its between-items divider"
        )
    }

    // MARK: - 2. Security pin

    /// The entire justification for rendering here. If this ever widens,
    /// the comments and body become an exfiltration surface for a worker
    /// that writes `[Approve](javascript:…)` into a card.
    @Test("only http, https and mailto links survive the allowlist")
    func theAllowlistStaysNarrow() throws {
        for allowed in ["https://example.com", "http://example.com", "mailto:a@b.c"] {
            let url = try #require(URL(string: allowed))
            #expect(
                ScarfLinkPolicy.allows(url),
                "\(allowed) should be an allowed document link"
            )
        }

        for refused in [
            "javascript:alert(1)",
            "data:text/html,<script>alert(1)</script>",
            "file:///etc/passwd",
            "x-scarf-danger:payload",
            "tel:+15555550100",
        ] {
            let url = try #require(URL(string: refused))
            #expect(
                !ScarfLinkPolicy.allows(url),
                "\(refused) must not be forwarded to the system opener"
            )
        }
    }

    // MARK: - 3. Deliberate iOS divergence

    /// iOS cannot use `MarkdownContentView` — it imports Marker, which is
    /// linked only to the macOS target and declares a macOS platform floor,
    /// and its code/table chrome uses `Color(.textBackgroundColor)`. iOS
    /// therefore still renders plain text, and this pins that so a future
    /// "restore parity" sweep finds a failing test instead of quietly
    /// reintroducing the un-allowlisted `AttributedString(markdown:)` path.
    @Test("the iOS detail sheet still renders plain text on purpose")
    func iOSStaysPlainTextOnPurpose() throws {
        let src = try Self.source("Scarf iOS/Kanban/ScarfGoKanbanDetailSheet.swift")

        #expect(
            src.contains("Text(body)"),
            "iOS body rendering changed without updating this test"
        )
        #expect(
            !src.contains("MarkdownContentView("),
            "iOS gained a markdown renderer — verify it carries the same link allowlist, then update this test"
        )
        #expect(
            !src.contains("AttributedString(markdown: body)"),
            "iOS renders the body with an un-allowlisted markdown parse"
        )
    }
}
