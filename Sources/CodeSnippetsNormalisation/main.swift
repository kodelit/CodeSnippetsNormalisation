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

struct Param {
    static let genDetails = "--gen-details"
}

let scriptPath = CommandLine.arguments.first!
var shouldGenDetail = CommandLine.arguments.contains(Param.genDetails)

var dirUrl = URL(string: scriptPath)!
dirUrl.deleteLastPathComponent()
let dir = dirUrl.absoluteString

//print(" Script path:", scriptPath, "\n dir:", dir)

let snippetsListFileName = "ListOfSnippets.md"
let snippetFileExt = ".codesnippet"

struct Snippet:Codable {
    var id:String
    var shortcut:String? = ""
    var name:String? = ""
    var lang:String? = ""
    var platform:String? = ""
    var summary:String? = ""
    var content:String? = ""

    private var _fileNameWithoutExtension:String? = nil
    var fileNameWithoutExtension:String {
        get { return _fileNameWithoutExtension ?? id}
        set { _fileNameWithoutExtension = newValue }
    }

    var displayName:String {
        return name ?? id
    }

    var displayLanguage:String {
        return self.lang?.components(separatedBy: ".").last ?? ""
    }

    var raw:[String:Any]? = nil

    enum CodingKeys:String, CodingKey {
        case shortcut = "IDECodeSnippetCompletionPrefix"
        case name = "IDECodeSnippetTitle"
        case lang = "IDECodeSnippetLanguage"
        case platform = "IDECodeSnippetPlatformFamily"
        case summary = "IDECodeSnippetSummary"
        case content = "IDECodeSnippetContents"
        case id = "IDECodeSnippetIdentifier"
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

    init(id:String) {
        self.id = id
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
        var row = Snippet.with(snippetDict) ?? Snippet(id: fileNameWithoutExtension)
        row.raw = snippetDict
        snippetsByFileName[fileName] = row
    }
    return snippetsByFileName
}

// MARK: - Normalising shortcut

func fixShortcuts(snippetsByFileName:[String: Snippet]) -> [String: Snippet] {
    let shortcutKey = Snippet.CodingKeys.shortcut.rawValue
    let keywords = ["classBody", "class_body", "doc", "example", "ext", "func", "impl", "inline", "mark", "mit", "podspec", "prop", "prot", "rlm", "rx", "stack", "usr", "var"]
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
            fixedSnippets[fileName] = row
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

func snippetDetailsRelativePath(for fileName:String, fileExtension:String? = "md") -> String {
    let fileExtension = fileExtension != nil ? ".\(fileExtension!)" : ""
    return "details/\(fileName)\(fileExtension)"
}

func genDetailsFile(for snippet:Snippet) {
    let hasShortcut = snippet.shortcut != nil && !snippet.shortcut!.isEmpty

    let content = """
    # \(snippet.displayName)
    - **shortcut**: \(hasShortcut ? "`\(snippet.shortcut!)`" : " ")
    - **language**: \(snippet.displayLanguage)
    - **platform**: \(snippet.platform ?? "")
    \(snippet.summary != nil ? "\n## Summary\n\(snippet.summary!)" : "")

    ## Code:
    ```\(snippet.displayLanguage.lowercased())\n\(snippet.content ?? "")\n```
    """
    let filePath = path(for: snippetDetailsRelativePath(for: snippet.fileNameWithoutExtension))
    do{
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }catch{
        print("Failed to save details:",error)
    }
}

func generateListFile(_ snippets:[Snippet]) {
    let terminalLink = "/Applications/Utilities/Terminal.app"
    let normalizationWithGeneratorCommand = "~/Library/Developer/Xcode/UserData/CodeSnippets/CodeSnippetsNormalisation \(Param.genDetails)"
    let moreDetailInfo = "> This file is generated by the `CodeSnippetsNormalisation` tool. If you need more detail about scnippets fire `CodeSnippetsNormalisation` tool form terminal with param `\(Param.genDetails)` to generate list containing also links to seperate file with descirption and code for each snippet type in [Terminal](\(terminalLink)): `\(normalizationWithGeneratorCommand)`"

    let isShortcutDifferentThanFileName:(Snippet) -> Bool = { $0.fileNameWithoutExtension != $0.shortcut }
    let hasOptionalColumn = snippets.first(where: isShortcutDifferentThanFileName ) != nil
    let optionalColumnName = hasOptionalColumn ? "file name (if different than shortcut)" : ""

    var fileContent = """
    ## Snippets list:
    \(!shouldGenDetail ? moreDetailInfo : "")

    shortcut | name | summary | language | platform |\(hasOptionalColumn ? " \(optionalColumnName) |" : "" )
    ---|---|---|---|---|\(hasOptionalColumn ? "---|" : "" )
    """

    /// Directory containing detail files of the snippets
    let detailsDir = path(for: snippetDetailsRelativePath(for: "", fileExtension: nil))
    let doesDirExist = FileManager.default.fileExists(atPath: detailsDir)

    // Remove old details dir if it exists
    if doesDirExist {
        do {
            try FileManager.default.removeItem(atPath: detailsDir)
        }catch{
            print("Could not remove `/details dir", error)
        }
    }

    // Create details dir needed
    if shouldGenDetail {
        if !FileManager.default.fileExists(atPath: detailsDir) {
            do {
                try FileManager.default.createDirectory(atPath: detailsDir, withIntermediateDirectories: true, attributes: nil)
            }catch{
                print(error)
                shouldGenDetail = false
            }
        }
    }

    for row in snippets {
        // add row to listing file content
        let lang = row.displayLanguage
        let snippetName = row.displayName
        let snippetDetailLink = shouldGenDetail ? "[\(snippetName)](details/\(row.fileNameWithoutExtension).md)" : snippetName
        let hasShortcut = row.shortcut != nil && !row.shortcut!.isEmpty
        var nextLine = "\n\(hasShortcut ? "`\(row.shortcut!)`" : " ")|\(snippetDetailLink)|\(row.summary ?? "")|\(lang)|\(row.platform ?? "All")|"

        // add value to optional collumn only if its different than shortcut, to distinguish this item
        if hasOptionalColumn && isShortcutDifferentThanFileName(row) {
            nextLine += "\(row.fileNameWithoutExtension)|"
        }
        fileContent.append(nextLine)

        // generate detail files
        if shouldGenDetail {
            genDetailsFile(for: row)
        }
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

