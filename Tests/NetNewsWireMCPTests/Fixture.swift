import Foundation
import GRDB
@testable import NetNewsWireMCPLib

// MARK: - Fixture Database
//
// These tests build a throwaway SQLite database whose schema mirrors
// NetNewsWire 7.1's ArticlesDatabase (articles with inline authors JSON,
// statuses, and the `search` FTS4 virtual table). They exercise the real query layer in
// `NNWDatabase` end-to-end without needing a live NetNewsWire install, so they
// run in CI. The schema here should be kept in sync with the live schema that
// the `testLiveSchemaMatches...` test validates when a real DB is present.

let fixtureOPML = """
<?xml version="1.0" encoding="UTF-8"?>
<opml version="2.0">
<head><title>Subscriptions</title></head>
<body>
    <outline text="Tech" title="Tech">
        <outline type="rss" title="Swift Blog" xmlUrl="https://swift.org/feed.xml" htmlUrl="https://swift.org"/>
        <outline type="rss" title="Apple Newsroom" xmlUrl="https://apple.com/feed.xml" htmlUrl="https://apple.com"/>
    </outline>
</body>
</opml>
"""

/// Timestamps used across the fixture (seconds since 1970).
enum T {
    static let a1 = 1_700_000_000.0
    static let a2 = 1_700_000_500.0
    static let a3 = 1_700_000_900.0
}

struct Fixture {
    let basePath: String

    init() throws {
        let fm = FileManager.default
        basePath = fm.temporaryDirectory
            .appendingPathComponent("nnw-fixture-\(UUID().uuidString)").path
        try fm.createDirectory(atPath: "\(basePath)/2_iCloud", withIntermediateDirectories: true)
        try fm.createDirectory(atPath: "\(basePath)/OnMyMac", withIntermediateDirectories: true)
        try Fixture.buildDatabase(at: "\(basePath)/2_iCloud/DB.sqlite3", populate: true)
        try Fixture.buildDatabase(at: "\(basePath)/OnMyMac/DB.sqlite3", populate: false)
        try fixtureOPML.write(toFile: "\(basePath)/2_iCloud/Subscriptions.opml", atomically: true, encoding: .utf8)
    }

    func database() throws -> NNWDatabase {
        try NNWDatabase(accountsBasePath: basePath)
    }

    /// Fill the (otherwise empty) OnMyMac account with `count` starred articles
    /// whose text fields are long, approximating a worst-case response size.
    func addLargeArticles(count: Int, bodyLength: Int = 500) throws {
        let queue = try DatabaseQueue(path: "\(basePath)/OnMyMac/DB.sqlite3")
        let longTitle = String(repeating: "Long headline words ", count: 6)  // 120 chars
        let body = String(repeating: "Body text with <b>markup</b>. ", count: bodyLength / 30 + 1)
        try queue.write { db in
            for i in 0..<count {
                let feed = "https://feeds.example.com/very/long/feed/path/number-\(i % 10)/rss.xml"
                try Fixture.insertArticle(
                    db, id: "big-\(i)", feedID: feed,
                    title: "\(longTitle)\(i)",
                    contentHTML: body,
                    url: "https://www.example.com/\(2026)/09/29/a-fairly-long-article-slug-that-goes-on-\(i)?utm_source=rss",
                    datePublished: T.a1 + Double(i), dateArrived: T.a1 + Double(i),
                    read: false, starred: true,
                    searchTitle: "\(longTitle)\(i)", searchBody: "headline body text"
                )
            }
        }
    }

    func cleanup() {
        try? FileManager.default.removeItem(atPath: basePath)
    }

    private static func buildDatabase(at path: String, populate: Bool) throws {
        let queue = try DatabaseQueue(path: path)
        try queue.write { db in
            // Schema mirrors NetNewsWire 7.1.1's DB.sqlite3 (verified against a
            // live install): authors are inline JSON on articles.authors, there
            // is no separate authors/authorsLookup table, and statuses has no
            // userDeleted column.
            try db.execute(sql: """
                CREATE TABLE articles (
                    articleID TEXT NOT NULL PRIMARY KEY,
                    feedID TEXT NOT NULL,
                    uniqueID TEXT NOT NULL,
                    title TEXT,
                    contentHTML TEXT,
                    contentText TEXT,
                    url TEXT,
                    externalURL TEXT,
                    summary TEXT,
                    imageURL TEXT,
                    bannerImageURL TEXT,
                    datePublished DATE,
                    dateModified DATE,
                    searchRowID INTEGER,
                    markdown TEXT,
                    authors TEXT
                );
                CREATE TABLE statuses (
                    articleID TEXT NOT NULL PRIMARY KEY,
                    read BOOL NOT NULL DEFAULT 0,
                    starred BOOL NOT NULL DEFAULT 0,
                    dateArrived DATE NOT NULL DEFAULT 0
                );
                CREATE VIRTUAL TABLE search USING fts4(title, body);
                """)

            guard populate else { return }

            try insertArticle(
                db, id: "a1", feedID: "https://swift.org/feed.xml",
                title: "Swift 6.3 Released",
                contentHTML: "<p>Concurrency improvements land in Swift</p>",
                contentText: "Plain-text concurrency notes",
                url: "https://swift.org/blog/swift-6-3",
                datePublished: T.a1, dateArrived: T.a1,
                read: true, starred: true,
                searchTitle: "Swift 6.3 Released", searchBody: "Concurrency improvements land in Swift",
                authors: #"[{"authorID":"auth-1","name":"Jane Developer","url":"https:\/\/jane.dev"}]"#
            )
            try insertArticle(
                db, id: "a2", feedID: "https://swift.org/feed.xml",
                title: "Rust vs Swift",
                contentText: "A friendly comparison",
                url: "https://swift.org/blog/rust-vs-swift",
                datePublished: T.a2, dateArrived: T.a2,
                read: false, starred: false,
                searchTitle: "Rust vs Swift", searchBody: "A friendly comparison"
            )
            // No datePublished: ordering must fall back to dateArrived.
            try insertArticle(
                db, id: "a3", feedID: "https://apple.com/feed.xml",
                title: "Apple Event",
                contentHTML: "<p>New hardware announced</p>",
                url: "https://apple.com/events",
                datePublished: nil, dateArrived: T.a3,
                read: true, starred: true,
                searchTitle: "Apple Event", searchBody: "New hardware announced"
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func insertArticle(
        _ db: Database,
        id: String,
        feedID: String,
        title: String,
        contentHTML: String? = nil,
        contentText: String? = nil,
        url: String?,
        datePublished: Double?,
        dateArrived: Double,
        read: Bool,
        starred: Bool,
        searchTitle: String,
        searchBody: String,
        authors: String? = nil
    ) throws {
        try db.execute(
            sql: "INSERT INTO search (title, body) VALUES (?, ?)",
            arguments: [searchTitle, searchBody]
        )
        let searchRowID = db.lastInsertedRowID

        try db.execute(sql: """
            INSERT INTO articles
                (articleID, feedID, uniqueID, title, contentHTML, contentText, url,
                 externalURL, summary, imageURL, bannerImageURL, datePublished, dateModified,
                 searchRowID, markdown, authors)
            VALUES (?, ?, ?, ?, ?, ?, ?, NULL, NULL, NULL, NULL, ?, NULL, ?, NULL, ?)
            """,
            arguments: [id, feedID, id, title, contentHTML, contentText, url, datePublished, searchRowID, authors]
        )
        try db.execute(
            sql: "INSERT INTO statuses (articleID, read, starred, dateArrived) VALUES (?, ?, ?, ?)",
            arguments: [id, read, starred, dateArrived]
        )
    }
}

/// Run `body` with a fresh fixture, cleaning up afterwards.
func withFixture(_ body: (Fixture, NNWDatabase) throws -> Void) throws {
    let fixture = try Fixture()
    defer { fixture.cleanup() }
    try body(fixture, fixture.database())
}

/// Async variant, for tests that drive the MCP server.
func withFixture(_ body: (Fixture, NNWDatabase) async throws -> Void) async throws {
    let fixture = try Fixture()
    defer { fixture.cleanup() }
    try await body(fixture, fixture.database())
}

