// This code is distributed under the terms and conditions of the MIT License:

// Copyright © 2019 Grzegorz Maciak.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation
// see: https://medium.com/@dmytro.anokhin/command-line-tool-using-swift-package-manager-and-utility-package-e0984224fc04

let scriptPath = CommandLine.arguments.first!
var dirUrl = URL(string: scriptPath)!
dirUrl.deleteLastPathComponent()
let dir = dirUrl.absoluteString

//print(" Script path:", scriptPath, "\n dir:", dir)

let snippetsListFileName = "ListOfSnippets.md"
let snippetFileExt = ".codesnippet"

struct Snippet:Codable {
    var fileNameWithoutExtension:String
    var shortcut:String? = ""
    var name:String? = ""
    var lang:String? = ""
    var platform:String? = ""
    var summary:String? = ""
    var content:String? = ""

    var raw:[String:Any]? = nil

    enum CodingKeys:String, CodingKey {
        case shortcut = "IDECodeSnippetCompletionPrefix"
        case name = "IDECodeSnippetTitle"
        case lang = "IDECodeSnippetLanguage"
        case platform = "IDECodeSnippetPlatformFamily"
        case summary = "IDECodeSnippetSummary"
        case content = "IDECodeSnippetContents"
        case fileNameWithoutExtension = "IDECodeSnippetIdentifier"
    }

    static func with(_ dict:[String: Any]?) -> Snippet? {
        guard let object = dict,
            // This is not efficient but clear and quick enough solution
            let data = try? JSONSerialization.data(withJSONObject: object, options: []),
            let row = try? JSONDecoder().decode(self, from: data) else
        {
                return nil
        }
        return row
    }

    init(fileName:String) {
        self.fileNameWithoutExtension = fileName
    }
}

func path(for fileName:String) -> String {
    let filePath = "\(dir)\(fileName)"
    return filePath
}

// MARK: - Parsing

func parseSnippets(snippetFileNames:[String]) -> [String: Snippet] {
    /// Snippets dictionary where `fileName` is a key and `SnippetsListRow` a value
    var snippetsByFileName: [String: Snippet] = [:]
    for fileName in snippetFileNames {
        /// original file path
        let filePath = path(for: fileName)

        /// snippet as dictionary
        var snippetDict = NSDictionary(contentsOfFile: filePath) as? [String: Any]

        // Fixing of the snippet file in case when user edits snippet in text
        // editor and forgets to use escaped form for placeholders
        if snippetDict == nil, var content = try? String(contentsOfFile: filePath, encoding: .utf8) {
            content = content.replacingOccurrences(of: "#>", with: "#&gt;").replacingOccurrences(of: "<#", with: "&lt;#")
            if let _ = try? content.write(toFile: filePath, atomically: true, encoding: .utf8) {
                snippetDict = NSDictionary(contentsOfFile: filePath) as? [String: Any]
            }
        }

        /// original file name without extension
        let fileNameWithoutExtension = fileName.replacingOccurrences(of: snippetFileExt, with: "")

        /// snippet metadata
        var row = Snippet.with(snippetDict) ?? Snippet(fileName: fileNameWithoutExtension)
        row.raw = snippetDict
        snippetsByFileName[fileName] = row
    }
    return snippetsByFileName
}

// MARK: - Normalising shortcut

func fixShortcuts(snippetsByFileName:[String: Snippet]) -> [String: Snippet] {
    let shortcutKey = Snippet.CodingKeys.shortcut.rawValue
    let keywords = ["classBody", "doc", "example", "ext", "func", "impl", "inline", "podspec", "prop", "prot", "mark", "mit", "rlm", "rx", "usr", "var"]
    let keywordsPriority = ["rx": 100, "rlm": 99, "impl": -1] // default priority is 0

    /// Separator to use in normalized version of the shortcut to separate prefixes
    let targetSeparator = "_"

    /// Known separators which can be used to separate prefixes.
    /// Any of this separators will be replaced by the `targetSeparator`
    let knownSeparators = "-_:"

    var fixedSnippets:[String: Snippet] = [:]
    for (fileName, row) in snippetsByFileName {

        /// original file path
        let filePath = path(for: fileName)

        guard let shortcut = row.shortcut else
        {
            // if somehow shippet could not be loaded or has no shortcut save its available metadata
            continue
        }

        /// all known prefixes included in shortcut
        var prefixes = keywords.reduce(into: [String](), { (result, key) in
            if let _ = shortcut.range(of: "\(key)[\(knownSeparators)]", options: .regularExpression) {
                result.append(key)
            }
        })

        /// shortcut with removed all prefixes and other allowed separators
        let trimmedShortcut = prefixes.reduce(shortcut, { (result, prefix) -> String in
            if let range = result.range(of: "\(prefix)[\(knownSeparators)]", options: .regularExpression) {
                return result.replacingCharacters(in: range, with: "").trimmingCharacters(in: CharacterSet(charactersIn: knownSeparators))
            }
            return result
        })

        // sort prefixes according to its priority to occure in file name and new shosrtcut
        prefixes.sort(by: { (lhs, rhs) -> Bool in
            let priority1 = keywordsPriority[lhs] ?? 0
            let priority2 = keywordsPriority[rhs] ?? 0
            return priority1 > priority2
        })

        // add trimmed shortcut to prefixes to join all components into the one string
        prefixes.append(trimmedShortcut)

        /// New valid shortcut and file name
        let newShortcut = prefixes.joined(separator: targetSeparator)

        // if shortcut is changed update shortcut in existing file
        var fixedRow = row
        fixedRow.fileNameWithoutExtension = newShortcut
        if shortcut != newShortcut {
            print("Shotcut Fix: \(shortcut) -> \(newShortcut)")
            if var dict = row.raw {
                dict[shortcutKey] = newShortcut
                (dict as NSDictionary).write(toFile: filePath, atomically: true)

                fixedRow.raw = dict
            }
            fixedRow.shortcut = newShortcut
        }
        fixedSnippets[fileName] = fixedRow
    }
    return fixedSnippets
}

// MARK: - Updating file name

func fixFileNames(snippetsByFileName:[String: Snippet]) {
    for (fileName, row) in snippetsByFileName {
        let newFileName = "\(row.fileNameWithoutExtension)\(snippetFileExt)"

        // fix file name if needed
        if fileName != newFileName {
            print("File name fix: \(fileName) -> \(newFileName)")
            let source = path(for: fileName)
            let target = path(for: newFileName)
            do {
                try FileManager.default.moveItem(atPath: source, toPath: target)
            }catch{
                print(error)
            }
        }
    }
}

// MARK: - Generating Snippets List

func generateListFile(_ snippets:[Snippet]) {
    var fileContent = "shortcut | name | summary | language | platform | file name (if different than shortcut)|  \n---|---|---|---|---|---|"
    for row in snippets {
        // add row to list.md
        let lang = row.lang?.components(separatedBy: ".").last ?? "All"
        let fileName = row.fileNameWithoutExtension != row.shortcut ? row.fileNameWithoutExtension : ""
        let nextLine = "\n\(row.shortcut ?? "")|\(row.name ?? "")|\(row.summary ?? "")|\(lang)|\(row.platform ?? "All")|\(fileName)|"
        fileContent.append(nextLine)
    }

    /// Snippets list file path
    let snippetsListFilePath = path(for: snippetsListFileName)
    do {
        try fileContent.write(toFile: snippetsListFilePath, atomically: true, encoding: .utf8)
    }catch{
        print(error)
    }
}

// MARK: - Main

if let files = try? FileManager.default.contentsOfDirectory(atPath: dir) {
    let snippetFileNames = files.filter { (path:String) -> Bool in
        return path.hasSuffix(snippetFileExt)
    }

    /// Snippets dictionary where `fileName` is a key and `SnippetsListRow` a value
    var snippetsByFileName = parseSnippets(snippetFileNames: snippetFileNames)
    snippetsByFileName = fixShortcuts(snippetsByFileName: snippetsByFileName)
    fixFileNames(snippetsByFileName: snippetsByFileName)

    /// Snippets sorted by its shortcut
    let sortedSnippets = snippetsByFileName.values.sorted(by: { $0.shortcut ?? "" > $1.shortcut ?? "" })

    generateListFile(sortedSnippets)
}

