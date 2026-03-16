# a2a-swift

Swift SDK for the A2A (Agent-to-Agent) protocol v1.0.

## GitHub Actions

### CI (`.github/workflows/ci.yml`)
- **Triggers**: Push to `main`, PRs targeting `main`
- **Concurrency**: Groups by ref, cancels in-progress runs
- **Jobs**:
  - `macOS` — `macos-latest`: `swift build` + `swift test`
  - `Linux` — `ubuntu-latest` with `swift:6.0` container: `swift build` + `swift test`
  - `iOS` — `macos-latest`: `xcodebuild build` (generic/platform=iOS)
  - `tvOS` — `macos-latest`: `xcodebuild build` (generic/platform=tvOS)
  - `watchOS` — `macos-latest`: `xcodebuild build` (generic/platform=watchOS)

### Release (`.github/workflows/release.yml`)
- **Trigger**: Manual `workflow_dispatch` with inputs:
  - `version` (required): semver string, e.g. `0.1.1`
  - `prerelease` (optional, default false): marks as pre-release
- **Jobs**:
  1. `validate` — runs on `macos-15`, selects Xcode 16.2, validates semver format, checks tag doesn't exist, builds, runs tests
  2. `release` — runs on `ubuntu-latest`, creates annotated git tag, pushes tag, creates GitHub release with auto-generated release notes (uses `softprops/action-gh-release@v2`)

## Release Process
1. Merge PR to `main`
2. Go to Actions → Release → Run workflow
3. Enter version (e.g. `0.1.1`) → triggers build, test, tag, release
4. SPM consumers update their `from:` version

## Project Structure
- `Sources/A2A/` — Core SDK (models, client, server)
- `Sources/A2AVapor/` — Vapor integration (`app.mountA2A(handler:)`)
- `Tests/A2ATests/` — Core SDK tests (Swift Testing framework)
- `Tests/A2AVaporTests/` — Vapor integration tests
- `Examples/` — Single-file usage examples
- `Samples/A2AServer/` — Dockerized Vapor server with product catalog agent + Ollama
- `Samples/A2AChatClient/` — macOS SwiftUI chat client with Foundation Models orchestration

## Testing
- Uses Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`)
- Run all: `swift test`
- Run specific suite: `swift test --filter EventQueueManagerTests`

## Current Version
- Latest release: `0.3.0` (A2AVapor integration target, AgentCardResolver with caching)
