# SwiftPlugin

SwiftPlugin is a Swift library for treating agent plugins as typed, validated,
portable `.plugin` packages.

It does not provide a marketplace, registry, downloader, or MCP process runner.
Its responsibility is to normalize marketplace artifacts into local `.plugin`
packages that Swift can parse, validate, install, and materialize safely.

```text
Marketplace artifact
  |
  v
*.plugin
  |
  v
SwiftPlugin parse / validate / install
  |
  v
Application runtime
```

## Package Format

```text
memory.plugin/
├── plugin.json
├── mcp.json
├── skills/
│   └── memory/
│       └── SKILL.md
├── runtimes/
│   └── memory-server/
├── resources/
└── trust.json
```

| File | Role |
|---|---|
| `plugin.json` | Canonical plugin manifest |
| `mcp.json` | Canonical MCP connection configuration |
| `skills/` | SwiftSkill-compatible skill directories |
| `runtimes/` | Optional runtime payloads for Node or native binary MCP servers |
| `resources/` | Supporting files used by skills or runtimes |
| `trust.json` | Digest, signature, and provenance metadata |

The full package specification is defined in
[docs/PLUGIN_SPEC.md](docs/PLUGIN_SPEC.md).

## Responsibilities

| SwiftPlugin does | SwiftPlugin does not do |
|---|---|
| Parse `.plugin` packages | Search a marketplace |
| Validate manifest, MCP, skill, runtime, and trust metadata | Download packages |
| Reject unsafe paths and symlinks | Run MCP server processes |
| Install packages into a plugin store | Monitor child processes |
| Generate provider compatibility files | Decide user trust UI |

## Installation

```swift
import SwiftPlugin

let source = URL(filePath: "/Downloads/memory.plugin", directoryHint: .isDirectory)
let store = URL.applicationSupportDirectory
    .appending(path: "Aurora/Plugins", directoryHint: .isDirectory)

let installedURL = try PluginInstaller(destinationRootURL: store)
    .install(from: source)
```

`install(from:)` validates the source package, writes to a temporary package,
validates the temporary package, and then replaces the installed package.

## Parsing And Validation

```swift
import SwiftPlugin

let packageURL = URL(filePath: "/path/to/memory.plugin", directoryHint: .isDirectory)
let plugin = try PluginParser().parse(at: packageURL)

let errors = PluginValidator().validationErrors(for: plugin)
try PluginValidator().validate(plugin)
```

Validation covers:

| Area | Checks |
|---|---|
| Package | `.plugin` extension, manifest presence |
| Manifest | identity, version, display name, capabilities |
| MCP | transport-specific fields, runtime references |
| Runtime | relative paths, entrypoint existence, duplicate IDs |
| Trust | executable runtimes require digest metadata |
| Filesystem | unsafe paths and symbolic links are rejected |

## Provider Compatibility

Canonical package files are visible files at the package root. Provider-specific
hidden files can be materialized from canonical data.

```swift
try PluginMaterializer().materializeCompatibilityFiles(
    for: plugin,
    provider: .claude,
    at: packageURL
)
```

For Claude compatibility this can generate:

```text
.claude-plugin/plugin.json
.mcp.json
```

These files are compatibility outputs, not the canonical source of truth.

## Store

```swift
let store = PluginStore(rootURL: storeURL)
let plugins = try store.discover()
let memory = try store.plugin(named: "memory")
try store.delete(named: "memory")
```

Plugin names are stored as `.plugin` package directories.

## Development

```bash
swift test
```

The test suite uses Swift Testing and covers parsing, writing, installation,
provider materialization, package extension validation, unsafe path rejection,
symlink rejection, and executable runtime trust requirements.
