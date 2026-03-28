# GenerateInterface

Auto-generate Swift interface modules from compiled modules using SourceKit and SwiftSyntax - eliminating unnecessary recompilation in modular iOS codebases.

## Why?

In large modular iOS projects, changing an implementation detail in one module triggers recompilation of every dependent module. **Interface modules** break this chain by exposing only the public API surface - dependents import the lightweight interface instead of the full implementation.

Maintaining these by hand is tedious and error-prone. This tool automates the entire process.

## What it does

- Extracts the public module interface via SourceKit (`source.request.editor.open.interface`)
- Rewrites the interface with SwiftSyntax - strips internal imports, removes `some`/`any` wrappers, simplifies types, filters builder classes, merges duplicate extensions
- Replaces declarations with original source versions when available (preserving doc comments, attributes, formatting)
- Creates the interface module directory with `Sources/`
- Rewrites `import Module` to `import ModuleInterface` across the codebase
- Updates `Project.swift` to register the new module with correct dependencies (Tuist-specific)

## Requirements

- macOS 13+, Swift 5.10+, Xcode (for SourceKit)

## Quick start

```bash
swift build -c release
# or: make build
```

A sample project is included:

```bash
cd SampleProject
./run-sample.sh              # dry run - preview generated interface
./run-sample.sh --write      # full pipeline - creates interface module, rewrites imports
```

Reset after a full run:

```bash
git checkout SampleProject/Project.swift
rm -rf SampleProject/libraries/business/UserProfileInterface
```

## Usage

### Direct invocation

```bash
export DYLD_FRAMEWORK_PATH="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/lib"

./generateInterface \
    "/path/to/Project.swift" \
    "MyModule" \
    "/path/to/modules" \
    "/path/to/compiler-args.txt"
```

**Arguments:**
- `projectSwiftPath` - Tuist `Project.swift` file
- `moduleName` - module to generate an interface for
- `modulesPath` - root directory containing all modules
- `compilerArgsPath` - file with Swift compiler arguments (one per line)

**Flags:**
- `--print-only` - preview generated interface without writing files

### Getting compiler arguments

Extract from Xcode build settings:

```bash
xcodebuild -workspace App.xcworkspace \
    -scheme "MyModule" -arch arm64 \
    -sdk iphonesimulator -configuration "Debug" \
    -showBuildSettingsForIndex -json 2>/dev/null > build_settings.json
```

Parse `swiftASTCommandArguments`, removing `-module-name` and the module name:

```bash
jq -r '.MyModule | to_entries[0].value.swiftASTCommandArguments[]' build_settings.json \
  | grep -v -e '-module-name' -e '^MyModule$' \
  > compiler-args.txt
```

### Ruby wrapper

The included `generateInterface.rb` automates compiler argument extraction:

```bash
ruby generateInterface.rb MyModule
ruby generateInterface.rb MyModule --print-only
```

The wrapper runs `xcodebuild -showBuildSettingsForIndex`, extracts and caches compiler arguments, then invokes the tool.

Environment variables: `WORKSPACE` (default: `App.xcworkspace`), `TOOL_PATH` (default: `tools/generateInterface`), `MODULES_PATH` (default: `libraries`).

## How it works

- **SourceKit** returns the full public interface of a compiled module (same as Xcode's "Generated Interface" view)
- **SwiftSyntax** parses and rewrites the interface at the AST level - structurally correct transformations, not string replacements
- **ProjectRewriter** manipulates Tuist `Module(...)` declarations to register the new interface module and update dependencies

## Limitations

- `Project.swift` rewriting is specific to Tuist projects using `Module(...)` declarations with `kind`, `moduleDependencies`, and `features` parameters - adapt `ProjectRewriter.swift` for other conventions
- Ruby wrapper assumes an Xcode workspace-based project
- Builder class filtering is project-specific behavior

## License

MIT - see [LICENSE](LICENSE).
