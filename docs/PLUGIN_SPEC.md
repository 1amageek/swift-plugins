# AURORA Plugin Package Specification

Status: v1  
Package extension: `.plugin`  
Primary implementation package: `SwiftPlugin`

## 1. Purpose

AURORA Plugin Package is a draggable package format that contains the
instructions, MCP connection definition, runtime requirements, and supporting
files needed to attach one capability bundle to AURORA.

```text
Skill sharing
SKILL.md
  |
  v
Agent instructions

Plugin sharing
*.plugin/
  |-- skills/
  |-- mcp.json
  |-- runtimes/
  v
Agent instructions + MCP connection + optional runtime
```

The package must be treated as one unit. AURORA should not connect MCP and
Skill files independently when they are part of the same plugin.

## 2. Package Identity

| Item | Requirement |
|---|---|
| Extension | `.plugin` |
| Filesystem form | Directory package |
| Runtime unit | One plugin package maps to one installed plugin |
| Canonical manifest | `plugin.json` at package root |
| Canonical MCP file | `mcp.json` at package root |
| Skill root | `skills/` |
| Install root on macOS app | `~/Library/Application Support/Aurora/Plugins/` |
| Install root for CLI/server use | Configurable, default may be `~/.aurora/plugins/` |

`.plugin` is intentionally a package extension, not a single archive. This
keeps drag-and-drop, inspection, signing, and incremental update behavior simple
on macOS.

Recommended macOS document type:

| Item | Value |
|---|---|
| Uniform Type Identifier | `com.salescore.aurora.plugin` |
| Filename extension | `plugin` |
| Conforms to | `com.apple.package` |
| Handler rank | Owner for AURORA, Alternate for helper tools |

## 3. Directory Layout

```text
Memory.plugin/
├── plugin.json
├── mcp.json
├── skills/
│   └── memory/
│       └── SKILL.md
├── runtimes/
│   └── memory-server/
├── resources/
├── providers/
│   └── claude/
└── trust.json
```

| Path | Required | Responsibility |
|---|---:|---|
| `plugin.json` | Yes | Package identity, version, capabilities, runtime declarations |
| `mcp.json` | Yes when MCP is used | MCP server connection definitions |
| `skills/` | Yes when skills are used | One or more SwiftSkill-compatible skill directories |
| `runtimes/` | No | Bundled executable assets, scripts, or runtime payloads |
| `resources/` | No | Static files consumed by skills or runtimes |
| `providers/` | No | Provider-specific compatibility files |
| `trust.json` | No in draft, recommended for shared packages | Digests, signature metadata, provenance |

## 4. Canonical Files

### 4.1 `plugin.json`

`plugin.json` is the source of truth for plugin metadata. It is provider-neutral.

Required fields:

| Field | Type | Description |
|---|---|---|
| `schemaVersion` | String | Plugin package schema version |
| `id` | String | Stable reverse-DNS or namespace-qualified identifier |
| `name` | String | Stable local package name |
| `displayName` | String | User-facing name |
| `version` | String | Semantic version |
| `capabilities` | Array | Declared capability kinds |

Optional fields:

| Field | Type | Description |
|---|---|---|
| `description` | String | Short user-facing description |
| `author` | Object | Author or organization metadata |
| `homepageURL` | String | Project page |
| `license` | String | License identifier or text reference |
| `runtime` | Object | Runtime requirements and launch declarations |
| `permissions` | Object | Requested file, network, and process permissions |
| `compatibility` | Object | Minimum host and platform constraints |
| `metadata` | Object | App-specific extension metadata |

Capability values:

| Capability | Meaning |
|---|---|
| `skill` | Provides one or more skills |
| `mcp` | Provides or connects MCP servers |
| `runtime` | Launches or requires a local process |
| `resource` | Provides supporting files |

### 4.2 `mcp.json`

`mcp.json` is the canonical MCP configuration inside an AURORA plugin package.
Hidden `.mcp.json` may be generated for provider compatibility, but it is not
the package source of truth.

```text
plugin package source
mcp.json
  |
  | materialize for provider compatibility when needed
  v
runtime/provider view
.mcp.json
```

Required top-level field:

| Field | Type | Description |
|---|---|---|
| `mcpServers` | Object | MCP server map keyed by server name |

Each server may either connect to an external endpoint or reference a declared
runtime.

| Server field | Type | Description |
|---|---|---|
| `type` | String | `stdio`, `http`, or `streamable_http` |
| `url` | String | Required for HTTP transports |
| `command` | String | Required for unmanaged stdio command launch |
| `args` | Array | Command arguments |
| `env` | Object | Environment values or placeholders |
| `runtimeRef` | String | Reference to a runtime declared in `plugin.json` |

## 5. Runtime Model

MCP may be backed by Node.js, a native binary, an external HTTP service, or no
local runtime. The plugin manifest must describe that requirement explicitly.

```text
Plugin
├─ skill only
├─ external HTTP MCP
├─ system Node MCP
└─ bundled binary MCP
```

Runtime kinds:

| Kind | Meaning | AURORA responsibility |
|---|---|---|
| `none` | No local process | Load skills/resources only |
| `externalHTTP` | MCP server is already reachable | Validate URL and connect |
| `node` | Requires Node.js to launch MCP | Check Node availability/version, launch process |
| `binary` | Uses bundled native executable | Validate trust, executable bit, platform, launch process |

Runtime declaration fields:

| Field | Type | Description |
|---|---|---|
| `id` | String | Runtime identifier referenced by `mcp.json` |
| `kind` | String | Runtime kind |
| `entrypoint` | String | Relative path or command |
| `args` | Array | Launch arguments |
| `requiredVersion` | String | Runtime version constraint |
| `platforms` | Array | Supported OS and architecture constraints |
| `environment` | Object | Environment variables supplied at launch |
| `workingDirectory` | String | Relative working directory |

V1 runtime policy:

| Policy | Requirement |
|---|---|
| No post-install scripts | Install must be a deterministic copy/validation step |
| No dependency install on first launch | Node payloads must be prebuilt or depend on system Node explicitly |
| Runtime paths are relative | Package must remain portable after drag-and-drop |
| Executable launch requires trust | Binary and Node runtimes must pass trust validation before launch |

## 6. Trust And Permissions

A `.plugin` package can contain executable code. Importing a plugin is therefore
a trust decision, not only a file copy.

```text
DnD package
  |
  v
Parse -> Validate structure -> Validate runtime -> Validate trust -> Install
```

Permission categories:

| Category | Examples | Validation |
|---|---|---|
| `network` | MCP HTTP endpoints, outbound runtime access | User-visible host list |
| `filesystem` | Resources, configured writable directories | Relative paths by default |
| `process` | Node or binary launch | Runtime declaration required |
| `environment` | Required secrets or variables | Explicit placeholder list |

`trust.json` should contain package digest metadata and signature/provenance
information. The first implementation may validate digests without enforcing
public-key signatures, but the file format should leave room for signatures.

## 7. Installation Semantics

The runtime should read installed packages from the plugin store, not directly
from an arbitrary drag-and-drop source path.

```text
User DnD
Some.plugin
  |
  v
SwiftPlugin parser + validator
  |
  v
Plugin store
~/Library/Application Support/Aurora/Plugins/Some.plugin
  |
  v
AURORA runtime
```

Install behavior:

| Step | Requirement |
|---|---|
| Parse | Read `plugin.json`, `mcp.json`, `skills/`, runtimes, resources |
| Validate | Fail before copy when required files or runtime declarations are invalid |
| Copy | Materialize the complete `.plugin` directory into the plugin store |
| Normalize | Preserve package-relative paths and visible canonical files |
| Provider materialization | Generate provider-specific hidden files only when needed |
| Activate | Runtime connects the installed package |

## 8. Provider Compatibility

AURORA plugin packages are provider-neutral. Provider-specific files belong
under `providers/` or are generated from canonical files during installation.

| Provider need | Canonical source | Materialized form |
|---|---|---|
| Claude plugin metadata | `plugin.json` | `providers/claude/plugin.json` or `.claude-plugin/plugin.json` |
| Claude MCP config | `mcp.json` | `.mcp.json` |
| Codex skills | `skills/` | Direct skill directories |

This avoids making hidden files the only authoritative source of runtime
configuration.

## 9. Validation Rules

| Rule | Failure |
|---|---|
| Package path ends with `.plugin` | Invalid package extension |
| `plugin.json` exists and decodes | Missing or invalid manifest |
| `schemaVersion` is supported | Unsupported schema |
| `id`, `name`, and `version` are present | Invalid identity |
| Declared capabilities match files | Capability/file mismatch |
| `mcp.json` exists when `mcp` capability is declared | Missing MCP configuration |
| Skills parse when `skill` capability is declared | Invalid skill |
| Runtime references resolve | Missing runtime declaration |
| Runtime paths stay inside package | Unsafe path traversal |
| Binary runtime matches platform | Unsupported runtime |
| Required placeholders are declared | Unresolved environment dependency |

## 10. SwiftPlugin Responsibilities

`SwiftPlugin` should provide typed APIs for package operations.

| Type | Responsibility |
|---|---|
| `Plugin` | In-memory representation of a `.plugin` package |
| `PluginManifest` | Typed `plugin.json` |
| `MCPConfiguration` | Typed `mcp.json` |
| `PluginRuntime` | Runtime requirement and launch description |
| `PluginParser` | Read a `.plugin` directory |
| `PluginValidator` | Validate structure, capabilities, MCP, skills, runtimes |
| `PluginWriter` | Write canonical `.plugin` packages |
| `PluginStore` | Manage installed plugin packages |
| `PluginInstaller` | Install validated packages into the store |
| `PluginMaterializer` | Generate provider-specific compatibility files |

## 11. Versioning

| Version field | Meaning |
|---|---|
| `schemaVersion` | Format compatibility for `SwiftPlugin` |
| `version` | Plugin release version |
| Runtime version | Required Node/binary/platform compatibility |

Schema changes that break parsing must increment `schemaVersion`. Plugin updates
must compare `id` first, then `version`.

## 12. Recommended Migration

| Phase | Change |
|---|---|
| 1 | Keep reading legacy `.mcp.json` and `.claude-plugin/plugin.json` |
| 2 | Add canonical `.plugin` writer using `plugin.json` and `mcp.json` |
| 3 | Install DnD packages into the plugin store |
| 4 | Generate provider compatibility files from canonical files |
| 5 | Make AURORA runtime consume only installed `.plugin` packages |
