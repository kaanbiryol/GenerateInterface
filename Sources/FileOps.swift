import Foundation

let fileManager = FileManager.default

func createInterfaceModuleDirectoryWithSource(_ directory: String, moduleName: String, fileContent: String) throws -> String  {
    let enumerator = fileManager.enumerator(atPath: directory)
    
    let contents = try fileManager.contentsOfDirectory(atPath: directory)
    
    for item in contents {
        let firstLevelPath = (directory as NSString).appendingPathComponent(item)
        var isDirectory: ObjCBool = false
        
        if fileManager.fileExists(atPath: firstLevelPath, isDirectory: &isDirectory) && isDirectory.boolValue {
            let secondLevelContents = try fileManager.contentsOfDirectory(atPath: firstLevelPath)
            
            for secondItem in secondLevelContents {
                let secondLevelPath = (firstLevelPath as NSString).appendingPathComponent(secondItem)
                
                if fileManager.fileExists(atPath: secondLevelPath, isDirectory: &isDirectory) && isDirectory.boolValue {
                    if secondItem == moduleName {
                        let interfacePath = firstLevelPath
                        let interfaceFolder = (interfacePath as NSString).appendingPathComponent("\(moduleName)Interface")
                        let sourcesFolder = (interfaceFolder as NSString).appendingPathComponent("Sources")
                        let testSupportFolder = (interfaceFolder as NSString).appendingPathComponent("TestSupport")
                        
                        try createDirectoryIfNeeded(at: interfaceFolder)
                        try createDirectoryIfNeeded(at: sourcesFolder)
                        try createDirectoryIfNeeded(at: testSupportFolder)
                        
                        let filePath = (sourcesFolder as NSString).appendingPathComponent("\(moduleName)Interface.swift")
                        try createFile(at: filePath, withContent: fileContent)
                        return filePath
                    }
                }
            }
        }
    }
    return ""
}

func rewriteImportStatementsToInterfaceModule(_ directory: String, moduleName: String) throws {
    let enumerator = fileManager.enumerator(atPath: directory)
    
    while let filePath = enumerator?.nextObject() as? String {
        let fullPath = (directory as NSString).appendingPathComponent(filePath)
        
        // Skip directories with "TestSupport" in their names, but process Tests
        let isTest = filePath.contains("Tests")
        if filePath.contains("TestSupport") && !isTest {
            enumerator?.skipDescendants()
            continue
        }
        
        if filePath.hasSuffix(".swift") {
            try processFile(at: fullPath, moduleName: moduleName, isTest: isTest)
        }
    }
}

private func createDirectoryIfNeeded(at path: String) throws {
    if !fileManager.fileExists(atPath: path) {
        try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        print("Created Interface directory: \(path)")
    }
}
private func createFile(at path: String, withContent content: String) throws {
    fileManager.createFile(atPath: path, contents: content.data(using: .utf8), attributes: nil)
}

private func processFile(at path: String, moduleName: String, isTest: Bool) throws {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    let lines = content.components(separatedBy: .newlines)
    
    var modifiedLines = [String]()
    var modified = false
    
    for line in lines {
        if line.trimmingCharacters(in: .whitespaces) == "import \(moduleName)", !isTest {
            modifiedLines.append("import \(moduleName)Interface")
            modified = true
        } else if isTest && line.trimmingCharacters(in: .whitespaces) == "import \(moduleName)TestSupport" {
            modifiedLines.append("import \(moduleName)InterfaceTestSupport")
            modified = true
        } else {
            modifiedLines.append(line)
        }
    }
    
    if modified {
        let modifiedContent = modifiedLines.joined(separator: "\n")
        try modifiedContent.write(toFile: path, atomically: true, encoding: .utf8)
        print("Modified import statements in file: \(path)")
    }
}
