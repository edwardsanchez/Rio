# Repository Guidelines

## Project Structure & Module Organization
- `Rio/` contains all SwiftUI sources; root views (`ContentView.swift`, `RioApp.swift`) and shared types live here.
- `Rio/Message/` holds chat presentation logic; `Bubble/` encapsulates bubble state machines, `Explosion/` stores Metal particle shaders, and `Tails/` renders bubble tails.
- `Rio/Cursive Letter/` covers the animated handwriting system with SVG assets; keep new glyph assets under `svg/`.
- `Assets.xcassets` houses color themes and image resources; update the catalog with descriptive namespaces.
- Build artifacts reside in `build/`; do not edit checked-in files there. External Swift packages belong under `Packages/`.

## Build, Test, and Development Commands
- `open Rio.xcodeproj` or launch via Xcode to work with the primary scheme `Rio`.
- `xcodebuild -scheme Rio -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` performs a CI-friendly build; ensure it passes before PRs.
- `xcodebuild test -scheme Rio -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` will execute XCTest suites once they exist.
- always run /opt/homebrew/bin/swiftlint --fix after each iteration
- run `swiftformat --config .swiftformat Rio` before sending changes

## Coding Style & Naming Conventions
- Follow Swift 5.9 defaults: four-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for members, and mark protocol conformances in dedicated extensions when practical.
- Prefer SwiftUI composition; keep animation logic in dedicated types (`BubbleAnimationState`, `CircleAnimationManager`) to preserve readability.
- Document non-obvious behaviors with succinct inline comments and favor `Logger` utilities instead of print statements.
- Prefer computed properties whenever an API exposes read-only data and doesn’t require inputs. If the body is just returning a stored value, a transformed collection, or any other pure expression, use var foo: T { ... } instead of func foo() -> T.
  -Keep true functions when the language or protocol demands it (e.g., RandomNumberGenerator.next()), or when call-site syntax should communicate “do work” (async operations, heavy computation, throws, mutating behavior). Those cases can’t be modeled as nonmutating computed properties anyway.
  - Static helpers follow the same rule: expose cached constants or composed values with static var, not static func.
  - When the API needs a result conditioned on parameters, needs to mutate state, or performs significant work that callers should treat as an action, leave it as a function.
  - In short: “If it’s parameterless, pure, and conceptually a value, make it a computed property; otherwise stick with a function.
- Do not use computed properties that are simply aliases to properties that are inside another struct, unless it adds semantic value.
- Do not use computed properties with simple logic if it's only being referenced once in the codebase.
- Things like: .animation(.easeIn) { content in is a real API. Don't fucking mess with it!

## Testing Guidelines
- No automated tests are checked in yet; introduce `RioTests/` mirroring the source tree and group files by feature (e.g., `Message/BubbleTests`).
- Use XCTest and, for view regressions, SwiftUI snapshot tools; cover new state machine branches and content detection paths.
- When touching Metal or animation timing, add quick-start previews plus unit coverage for configuration structs; run `xcodebuild test …` locally.

## Commit & Pull Request Guidelines
- Commits in history are short, imperative statements (e.g., “Remove matched Geometry”); continue that style and scope related changes together.
- Reference tickets with `#123` when applicable and avoid bundling generated `build/` updates.
- PRs should outline user-facing changes, include before/after screenshots or screen recordings for UI tweaks, and mention impacted files such as `MessageBubbleView.swift`.
- Link to `TODO.md` items resolved or introduced, and call out follow-up work if animations or assets remain unfinished.
