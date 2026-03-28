import Foundation
import SourceKittenFramework

func moduleInterfaceSourceText(moduleName: String, compilerArgs: [String]) throws -> String {
    let yaml = moduleInterfaceRequest(moduleName: moduleName, compilerArgs: compilerArgs)
    let request = SourceKittenFramework.Request.yamlRequest(yaml: yaml)
    let response = try request.send()
    let data = toJSON(toNSDictionary(response)).data(using: .utf8)!
    let decoder = JSONDecoder()
    let sourceFile = try decoder.decode(SourceFile.self, from: data)
    return sourceFile.sourceText
}

struct SourceFile: Codable {
    let sourceText: String
    
    enum CodingKeys: String, CodingKey {
        case sourceText = "key.sourcetext"
    }
}

private func moduleInterfaceRequest(moduleName: String, compilerArgs: [String]) -> String {
    var request = """
    key.request: source.request.editor.open.interface
    key.name: "\(UUID().uuidString)"
    key.modulename: "\(moduleName)"
    key.toolchains:
        - "com.apple.dt.toolchain.XcodeDefault"
    key.compilerargs:\n
    """
    for arg in compilerArgs {
        let argString = """
        - "\(arg)"\n
    """
        request.append(argString)
    }
    return request
}
