//
//  Winetricks.swift
//  Whisky
//
//  This file is part of Whisky.
//
//  Whisky is free software: you can redistribute it and/or modify it under the terms
//  of the GNU General Public License as published by the Free Software Foundation,
//  either version 3 of the License, or (at your option) any later version.
//
//  Whisky is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
//  without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//  See the GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License along with Whisky.
//  If not, see https://www.gnu.org/licenses/.
//

import Foundation
import AppKit
import WhiskyKit

enum WinetricksCategories: String {
    case apps
    case benchmarks
    case dlls
    case fonts
    case games
    case settings
}

struct WinetricksVerb: Identifiable {
    var id = UUID()

    var name: String
    var description: String
}

struct WinetricksCategory {
    var category: WinetricksCategories
    var verbs: [WinetricksVerb]
}

class Winetricks {
    static let winetricksURL: URL = WhiskyWineInstaller.libraryFolder
        .appending(path: "winetricks")
    static let winetricksRemoteURL = "https://raw.githubusercontent.com/Winetricks/winetricks/" +
                                     "refs/heads/master/src/winetricks"
    static let verbsRemoteURL = "https://raw.githubusercontent.com/Winetricks/winetricks/" +
                                 "refs/heads/master/files/verbs/all.txt"
    static let verbsURL: URL = WhiskyWineInstaller.libraryFolder.appending(path: "verbs.txt")

    /// Downloads the latest winetricks script and verbs file, makes them executable
    static func downloadWinetricks() async throws {
        guard let winetricksUrl = URL(string: winetricksRemoteURL),
              let verbsUrl = URL(string: verbsRemoteURL) else {
            throw URLError(.badURL)
        }
        // Ensure the Libraries directory exists
        let librariesDir = WhiskyWineInstaller.libraryFolder
        if !FileManager.default.fileExists(atPath: librariesDir.path) {
            try FileManager.default.createDirectory(at: librariesDir, withIntermediateDirectories: true)
        }
        // Download the winetricks script
        let (winetricksData, _) = try await URLSession.shared.data(from: winetricksUrl)
        // Download the verbs file (all.txt)
        let (verbsData, _) = try await URLSession.shared.data(from: verbsUrl)
        // Write to the winetricks file
        try winetricksData.write(to: winetricksURL)
        // Write to the verbs.txt file
        try verbsData.write(to: verbsURL)
        // Make the winetricks file executable
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: winetricksURL.path)
        print("Winetricks and verbs downloaded successfully:")
        print("- Winetricks: \(winetricksURL.path)")
        print("- Verbs: \(verbsURL.path)")
    }
    /// Forces a re-download of the winetricks script and verbs file
    static func updateWinetricks() async throws {
        // Remove existing files if they exist
        if FileManager.default.fileExists(atPath: winetricksURL.path) {
            try FileManager.default.removeItem(at: winetricksURL)
        }
        if FileManager.default.fileExists(atPath: verbsURL.path) {
            try FileManager.default.removeItem(at: verbsURL)
        }
        // Download fresh copies
        try await downloadWinetricks()
    }

    static func runCommand(command: String, bottle: Bottle) async {
        // Ensure winetricks and verbs file are downloaded
        do {
            if !FileManager.default.fileExists(atPath: winetricksURL.path) ||
               !FileManager.default.fileExists(atPath: verbsURL.path) {
                try await downloadWinetricks()
            }
        } catch {
            print("Failed to download winetricks: \(error)")
            await MainActor.run {
                let alert = NSAlert()
                alert.messageText = String(localized: "alert.message")
                alert.informativeText = "Failed to download winetricks: \(error.localizedDescription)"
                alert.alertStyle = .critical
                alert.addButton(withTitle: String(localized: "button.ok"))
                alert.runModal()
            }
            return
        }
        guard let resourcesURL = Bundle.main.url(forResource: "cabextract", withExtension: nil)?
            .deletingLastPathComponent() else { return }
        // swiftlint:disable:next line_length
        let winetricksCmd = #"PATH=\"\#(WhiskyWineInstaller.binFolder.path):\#(resourcesURL.path(percentEncoded: false)):$PATH\" WINE=wine WINEPREFIX=\"\#(bottle.url.path)\" \"\#(winetricksURL.path(percentEncoded: false))\" \#(command)"#

        let script = """
        tell application "Terminal"
            activate
            do script "\(winetricksCmd)"
        end tell
        """

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)

            if let error = error {
                print(error)
                if let description = error["NSAppleScriptErrorMessage"] as? String {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = String(localized: "alert.message")
                        alert.informativeText = String(localized: "alert.info")
                            + " \(command): "
                            + description
                        alert.alertStyle = .critical
                        alert.addButton(withTitle: String(localized: "button.ok"))
                        alert.runModal()
                    }
                }
            }
        }
    }

    static func parseVerbs() async -> [WinetricksCategory] {
        // Ensure verbs file exists
        do {
            if !FileManager.default.fileExists(atPath: verbsURL.path) {
                try await downloadWinetricks()
            }
        } catch {
            print("Failed to download verbs file: \(error)")
            return []
        }
        // Read the local verbs file
        let verbs: String = {
            do {
                return try String(contentsOf: verbsURL, encoding: .utf8)
            } catch {
                print("Failed to read verbs file: \(error)")
                return ""
            }
        }()

        // Read the file line by line
        let lines = verbs.components(separatedBy: "\n")
        var categories: [WinetricksCategory] = []
        var currentCategory: WinetricksCategory?

        for line in lines {
            // Categories are label as "===== <name> ====="
            if line.starts(with: "=====") {
                // If we have a current category, add it to the list
                if let currentCategory = currentCategory {
                    categories.append(currentCategory)
                }

                // Create a new category
                // Capitalize the first letter of the category name
                let categoryName = line.replacingOccurrences(of: "=====", with: "").trimmingCharacters(in: .whitespaces)
                if let cateogry = WinetricksCategories(rawValue: categoryName) {
                    currentCategory = WinetricksCategory(category: cateogry,
                                                         verbs: [])
                } else {
                    currentCategory = nil
                }
            } else {
                guard currentCategory != nil else {
                    continue
                }

                // If we have a current category, add the verb to it
                // Verbs eg. "3m_library               3M Cloud Library (3M Company, 2015) [downloadable]"
                let verbName = line.components(separatedBy: " ")[0]
                let verbDescription = line.replacingOccurrences(of: "\(verbName) ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentCategory?.verbs.append(WinetricksVerb(name: verbName, description: verbDescription))
            }
        }

        // Add the last category
        if let currentCategory = currentCategory {
            categories.append(currentCategory)
        }

        return categories
    }
}
