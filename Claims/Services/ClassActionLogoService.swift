//
//  ClassActionLogoService.swift
//  Claims
//
//  Fetches the ClassAction.org settlements page and extracts logo image URLs
//  from each listing. Pairs each data-src with the immediately preceding
//  data-name and data-slug so images match the correct settlement.
//

import Foundation

struct ClassActionLogoMaps {
    /// slug (lowercased) -> full image URL. Use when settlement.sourceId matches ClassAction slug.
    var slugToURL: [String: String] = [:]
    /// normalized name -> full image URL. Use when name matches.
    var nameToURL: [String: String] = [:]
}

enum ClassActionLogoService {
    private static let settlementsURL = URL(string: "https://www.classaction.org/settlements")!
    private static let baseURL = "https://www.classaction.org"

    /// Fetches the settlements page and returns slug->URL and name->URL maps.
    /// Each image is paired with the *immediately preceding* data-name and data-slug so
    /// settlements get the correct logo.
    static func fetchLogoMaps() async -> ClassActionLogoMaps {
        do {
            let (data, _) = try await URLSession.shared.data(from: settlementsURL)
            guard let html = String(data: data, encoding: .utf8) else { return ClassActionLogoMaps() }
            return parseLogoMaps(from: html)
        } catch {
            print("ClassActionLogoService: fetch failed \(error)")
            return ClassActionLogoMaps()
        }
    }

    /// For each data-src image, find the last data-name and data-slug *before* it in the HTML,
    /// so we never associate an image with a different card.
    private static func parseLogoMaps(from html: String) -> ClassActionLogoMaps {
        var slugToURL: [String: String] = [:]
        var nameToURL: [String: String] = [:]
        let srcPattern = #"data-src="(/media/[^"]+\.(?:jpg|jpeg|png|webp))""#
        let namePattern = #"data-name="([^"]+)""#
        let slugPattern = #"data-slug="([^"]+)""#
        guard let srcRegex = try? NSRegularExpression(pattern: srcPattern),
              let nameRegex = try? NSRegularExpression(pattern: namePattern),
              let slugRegex = try? NSRegularExpression(pattern: slugPattern) else {
            return ClassActionLogoMaps()
        }
        let fullRange = NSRange(html.startIndex..., in: html)
        let srcMatches = srcRegex.matches(in: html, range: fullRange)
        for srcMatch in srcMatches {
            guard srcMatch.numberOfRanges >= 2,
                  let srcRange = Range(srcMatch.range(at: 1), in: html) else { continue }
            let src = String(html[srcRange])
            let fullURL = src.hasPrefix("http") ? src : (baseURL + src)
            // Look only at HTML *before* this data-src
            let endOfPrefix = srcMatch.range.location
            let prefixRange = NSRange(location: 0, length: endOfPrefix)
            let prefix = (html as NSString).substring(with: prefixRange)
            // Last data-name before this data-src = name for this image
            let nameMatches = nameRegex.matches(in: prefix, range: NSRange(prefix.startIndex..., in: prefix))
            let name = nameMatches.last.flatMap { m -> String? in
                guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: prefix) else { return nil }
                return String(prefix[r])
            }
            // Last data-slug before this data-src = slug for this image
            let slugMatches = slugRegex.matches(in: prefix, range: NSRange(prefix.startIndex..., in: prefix))
            let slug = slugMatches.last.flatMap { m -> String? in
                guard m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: prefix) else { return nil }
                return String(prefix[r])
            }
            if let slug = slug, !slug.isEmpty {
                slugToURL[slug.lowercased()] = fullURL
            }
            if let name = name, !name.isEmpty {
                nameToURL[normalizeName(name)] = fullURL
            }
        }
        return ClassActionLogoMaps(slugToURL: slugToURL, nameToURL: nameToURL)
    }

    /// Normalize for matching: lowercase, trim, collapse spaces, remove "Class Action Settlement" suffix.
    static func normalizeName(_ name: String) -> String {
        var s = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in [" class action settlement", " - class action settlement"] {
            if s.hasSuffix(suffix) { s = String(s.dropLast(suffix.count)) }
        }
        s = s.replacingOccurrences(of: "  ", with: " ")
        while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Build a slug from a settlement name for fallback matching (e.g. "23andMe - Data Breach" -> "23andme-data-breach").
    static func slugFromName(_ name: String) -> String {
        let n = normalizeName(name)
        return n
            .replacingOccurrences(of: " - ", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "&", with: "and")
            .unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" }
            .map(String.init)
            .joined()
    }
}
