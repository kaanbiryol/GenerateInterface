# GenerateInterface

A command-line tool that automatically generates Swift interface modules from compiled module interfaces using SourceKit and SwiftSyntax.

## The Problem

In large modular iOS codebases, modules often depend on each other's full implementations even when they only need access to the public API. This means changing an implementation detail in one module can trigger recompilation of all dependent modules, slowing down builds significantly.

**Interface modules** solve this by extracting a module's public API surface into a separate, lightweight module. Dependents import the interface module instead of the full implementation, so implementation changes no longer cascade rebuilds across the dependency graph.

Creating and maintaining these interface modules by hand is tedious and error-prone. This tool automates the process.

## What It Does

Given a module name and its compiler arguments, the tool:

1. **Extracts the module interface** via SourceKit (the same engine Xcode uses for code completion and indexing)
2. **Rewrites the interface** using SwiftSyntax - strips private/internal imports (prefixed with `_`), removes `some`/`any` type erasure wrappers, simplifies member type syntax, filters out builder classes, and merges duplicate extensions
3. **Replaces declarations** with their original source versions when available (preserving doc comments, attributes, and formatting)
4. **Creates the interface module directory** with `Sources/` and `TestSupport/` folders
5. **Rewrites import statements** across the codebase (`import Module` -> `import ModuleInterface`)
6. **Updates Project.swift** to register the new interface module with the correct dependencies (Tuist-specific)

## Requirements

- macOS 13+
- Xcode (for SourceKit)
- Swift 5.10+

## Installation

```bash
# Build from source
swift build -c release

# Or use the Makefile (builds for arm64)
make build
```

## Usage

### Direct invocation

```bash
./generateInterface \
    "/path/to/Project.swift" \
    "MyModule" \
    "/path/to/modules" \
    "/path/to/compiler-args.txt"
```

**Arguments:**
- `projectSwiftPath` - path to the Tuist `Project.swift` file
- `moduleName` - name of the module to generate an interface for
- `modulesPath` - root directory containing all modules
- `compilerArgsPath` - path to a file containing Swift compiler arguments (one per line)

**Flags:**
- `--print-only` - preview the generated interface without writing any files

### With the Ruby wrapper

The included `generateInterface.rb` script automates compiler argument extraction from Xcode build settings:

```bash
ruby generateInterface.rb MyModule
ruby generateInterface.rb MyModule --print-only
```

The wrapper:
1. Runs `xcodebuild -showBuildSettingsForIndex` for the module's scheme
2. Extracts Swift compiler arguments from the build settings
3. Caches build settings to avoid repeated Xcode calls
4. Invokes the Swift tool with the extracted arguments

Configure the wrapper by setting these environment variables:
- `WORKSPACE` - Xcode workspace name (default: `App.xcworkspace`)
- `TOOL_PATH` - path to the built `generateInterface` binary (default: `tools/generateInterface`)
- `MODULES_PATH` - path to the modules directory (default: `libraries`)

## How It Works

The core pipeline uses two Apple frameworks:

- **SourceKittenFramework** - sends a `source.request.editor.open.interface` request to Xcode's SourceKit daemon, which returns the full public interface of a compiled module (the same text you see in Xcode's "Generated Interface" view)
- **SwiftSyntax** - parses and rewrites the generated interface at the AST level, ensuring transformations are structurally correct rather than fragile string replacements

The `ProjectRewriter` manipulates Tuist's `Module(...)` declarations via SwiftSyntax to add the new interface module definition, update dependency lists, and wire up test support targets.

## Limitations

- The `Project.swift` rewriting is specific to a Tuist project structure using `Module(...)` declarations with `kind`, `moduleDependencies`, and `features` parameters. You may need to adapt `ProjectRewriter.swift` for your project's conventions.
- The Ruby wrapper assumes an Xcode workspace-based project. Adjust if using a different build system.
- Builder class filtering (`classes inheriting from Builder are excluded`) is project-specific behavior.

## License

MIT - see [LICENSE](LICENSE).
