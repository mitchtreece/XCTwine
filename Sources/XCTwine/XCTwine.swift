//
//  XCTwine.swift
//  XCTwine
//
//  Created by Mitch Treece on 3/8/24.
//

// xcstrings format:
//
//{
//  "sourceLanguage" : "en",
//  "strings" : {
//    "MY_STRING_KEY" : {
//      "comment" : "This is a really cool key",
//      "extractionState" : "manual",
//      "localizations" : {
//        "en" : {
//          "stringUnit" : {
//            "state" : "translated",
//            "value" : "My string value"
//          }
//        },
//        "es" : {
//          "stringUnit" : {
//            "state" : "translated",
//            "value" : "Mi valor de cadena"
//          }
//        }
//      }
//    }
//  },
//  "version" : "1.0"
//}

import Foundation
import ArgumentParser
import Rainbow


@main
struct XCTwine: ParsableCommand {
    
    @Argument(help: "The input xcstring file")
    private var inputFile: File
    
    @Argument(help: "The output string-extension file")
    private var outputFile: File
    
    @Option(
        name: .shortAndLong,
        help: "The output string-extension namespace"
    )
    private var namespace: String?
    
    @Option(
        name: [
            .customShort("f"),
            .customLong("format")
        ],
        help: "Output localization key format [none, camel, pascal]"
    )
    private var keyFormat: KeyFormat = .camel
    
    static let configuration = CommandConfiguration(
        commandName: "xctwine",
        abstract: "A Swift command-line tool for translating xcstring catalogue's into typed string extensions"
    )
    
    private static let stringsFileExtension: String = "xcstrings"
    private static let swiftFileExtension: String = "swift"
    
    mutating func run() throws {
        
        guard self.inputFile.exists else {
            error(.inputFileNotFound)
            return
        }
        
        guard let inputExtension = self.inputFile.extension,
              inputExtension == Self.stringsFileExtension else {
            
            error(.inputFileInvalidExtension)
            return
            
        }
        
        guard let outputExtension = self.outputFile.extension,
              outputExtension == Self.swiftFileExtension else {
            
            error(.outputFileInvalidExtension)
            return
            
        }
        
        log("🧶 Translating \(self.inputFile.filename.green.bold) → \(self.outputFile.filename.green.bold)")
        
        guard let inputFileJson = getJsonFromFile(self.inputFile) else {
            error(.inputFileJsonSerialization)
            return
        }
        
        guard let inputFileStringsJson = inputFileJson["strings"] as? [String: Any] else {
            error(.inputFileInvalidJson)
            return
        }
        
        let entries = inputFileStringsJson.map { pair in
            
            let payload = (pair.value as? [String: Any])
            
            return Entry(
                key: pair.key,
                format: self.keyFormat,
                comment: payload?["comment"] as? String
            )
            
        }
            .sorted(by: { $0.key < $1.key })
        
        guard !entries.isEmpty else {
            error("No localization entries, exiting")
            return
        }
        
        // Input localization keys
        
        log("🔑 Found \(entries.count) localization entry(s)")
        
        for entry in entries {
            log("   ﹂\(entry.key.green)")
        }
        
        // Generate output file
        
        var generateMessage = "📝 Creating \(self.outputFile.filename.green.bold) extension file"
        
        switch self.keyFormat {
        case .none: generateMessage += " (unformatted)".yellow
        case .camel: generateMessage += " (camel-formatted)".yellow
        case .pascal: generateMessage += " (pascal-formatted)".yellow
        }
        
        log(generateMessage)
        
        let output = buildOutputString(entries: entries)
        
        guard let outputData = output.data(using: .utf8) else {
            error(.outputDataInvalid)
            return
        }
        
        do {
            
            try outputData
                .write(to: self.outputFile.pathUrl)
            
        }
        catch {
            self.error(.outputFileFailedToWrite)
        }
        
        // Done
        
        log("🎉 Successfully generated \(self.outputFile.path.green.bold)")
        
    }
    
    // MARK: Private
    
    private func buildOutputString(entries: [Entry]) -> String {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d/m/yy"
        
        let dateString = formatter
            .string(from: Date())
        
        var string = """
        //
        // \(self.outputFile.filename)
        //
        // Created by XCTwine on \(dateString).
        //
        """
        
        string += "\n\n"
        string += "extension String /* XCTwine */ {"
        string += "\n\n"
        
        if let namespace = self.namespace {
            
            string += "    struct XCTwine /* Namespace */ {\n\n"
            
            for entry in entries {
                
                if let comment = entry.comment {
                    string += "        /// \(comment)\n"
                }
                
                string += "        let \(entry.formattedKey): String = \"\(entry.key)\"\n\n"
                
            }
            
            string += "    }\n\n"
            
            string += "    /// Localization namespace generated by XCTwine.\n"
            string += "    static var \(namespace): XCTwine {\n"
            string += "        return XCTwine()\n"
            string += "    }\n\n"
            
        }
        else {
            
            for entry in entries {
                
                if let comment = entry.comment {
                    string += "    /// \(comment)\n"
                }
                
                string += "    static let \(entry.formattedKey): String = \"\(entry.key)\"\n\n"
                
            }
            
        }
        
        string += "}"
        
        return string
        
    }
    
    private func getJsonFromFile(_ file: File) -> [String: Any]? {
        
        do {
            
            let data = try Data(contentsOf: file.pathUrl)
            
            let json = try JSONSerialization
                .jsonObject(with: data)
            
            return json as? [String: Any]
            
        }
        catch {
            return nil
        }
        
    }
    
    private func log(_ message: String) {
        print(message.cyan)
    }
    
    private func error(_ message: String) {
        print("😢 \(message)".red)
    }
    
    private func error(_ error: XCTwineError) {
        self.error(error.description)
    }
    
}
