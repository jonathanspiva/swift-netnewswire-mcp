import Foundation

public enum Formatters {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.timeZone = .current
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    /// Format a Unix timestamp to a readable date string
    public static func formatDate(_ timestamp: Double?) -> String {
        guard let timestamp, timestamp > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: timestamp)
        return dateFormatter.string(from: date)
    }

    /// Format a Unix timestamp to a short date string (date only)
    public static func shortDate(_ timestamp: Double?) -> String {
        guard let timestamp, timestamp > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: timestamp)
        return shortDateFormatter.string(from: date)
    }

    /// Escape pipe characters for markdown table cells
    public static func escapeTableCell(_ value: String?) -> String {
        (value ?? "-").replacingOccurrences(of: "|", with: "\\|")
    }

    /// Truncate a string to a max length
    public static func truncate(_ value: String?, maxLength: Int = 80) -> String {
        guard let value, !value.isEmpty else { return "-" }
        if value.count <= maxLength { return value }
        return String(value.prefix(maxLength)) + "..."
    }

    /// Format an article list as a markdown table
    public static func formatArticleTable(_ articles: [ArticleWithStatus], title: String) -> String {
        let esc = escapeTableCell
        var lines: [String] = [title]
        if articles.isEmpty {
            lines.append("No articles found.")
        } else {
            lines.append("| Article ID | Title | Feed | Date | Starred | URL |")
            lines.append("|------------|-------|------|------|---------|-----|")
            for article in articles {
                let articleID = esc(article.articleID)
                let articleTitle = esc(truncate(article.title, maxLength: 60))
                let feedID = esc(truncate(article.feedID, maxLength: 40))
                let date = shortDate(article.datePublished ?? article.dateArrived)
                let starred = article.starred ? "Yes" : "No"
                let url = article.url ?? article.externalURL ?? "-"
                lines.append("| \(articleID) | \(articleTitle) | \(feedID) | \(date) | \(starred) | \(url) |")
            }
        }
        lines.append("\nTotal: \(articles.count) articles")
        return lines.joined(separator: "\n")
    }

    /// Format a single article with full details
    public static func formatArticleDetail(_ article: ArticleWithStatus, authors: [Author]) -> String {
        var lines: [String] = ["# Article\n"]
        lines.append("- **ID**: `\(article.articleID)`")
        if let title = article.title {
            lines.append("- **Title**: \(title)")
        }
        lines.append("- **Feed**: \(article.feedID)")
        lines.append("- **Published**: \(formatDate(article.datePublished))")
        lines.append("- **Arrived**: \(formatDate(article.dateArrived))")
        if let url = article.url {
            lines.append("- **URL**: \(url)")
        }
        if let externalURL = article.externalURL, externalURL != article.url {
            lines.append("- **External URL**: \(externalURL)")
        }
        lines.append("- **Starred**: \(article.starred ? "Yes" : "No")")
        lines.append("- **Read**: \(article.read ? "Yes" : "No")")

        if !authors.isEmpty {
            let authorNames = authors.compactMap(\.name).joined(separator: ", ")
            if !authorNames.isEmpty {
                lines.append("- **Authors**: \(authorNames)")
            }
        }

        if let summary = article.summary, !summary.isEmpty {
            lines.append("\n## Summary\n")
            lines.append(summary)
        }

        if let html = article.contentHTML, !html.isEmpty {
            lines.append("\n## Content (HTML)\n")
            lines.append(html)
        } else if let text = article.contentText, !text.isEmpty {
            lines.append("\n## Content\n")
            lines.append(text)
        }

        return lines.joined(separator: "\n")
    }

    /// Format feed list as a markdown table
    public static func formatFeedTable(_ feeds: [FeedInfo]) -> String {
        let esc = escapeTableCell
        var lines: [String] = ["# Subscribed Feeds\n"]
        if feeds.isEmpty {
            lines.append("No feeds found.")
        } else {
            lines.append("| Feed | Folder | URL |")
            lines.append("|------|--------|-----|")
            for feed in feeds {
                let title = esc(feed.title)
                let folder = esc(feed.folder)
                lines.append("| \(title) | \(folder) | \(feed.xmlUrl) |")
            }
        }
        lines.append("\nTotal: \(feeds.count) feeds")
        return lines.joined(separator: "\n")
    }

    /// Format article counts
    public static func formatCounts(account: String, total: Int, starred: Int, unread: Int) -> String {
        var lines: [String] = ["# Article Counts: \(account)\n"]
        lines.append("| Metric | Count |")
        lines.append("|--------|-------|")
        lines.append("| Total articles | \(total) |")
        lines.append("| Starred | \(starred) |")
        lines.append("| Unread | \(unread) |")
        return lines.joined(separator: "\n")
    }

    /// Format account list
    public static func formatAccountList(_ accounts: [NNWAccount]) -> String {
        var lines: [String] = ["# NetNewsWire Accounts\n"]
        for account in accounts {
            lines.append("- **\(account.name)**")
            lines.append("  Path: `\(account.path)`")
            lines.append("  OPML: \(account.opmlPath != nil ? "Yes" : "No")")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
