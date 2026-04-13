# Rambler AGENTS.md

## Product
Rambler is an iPhone-first iOS 26+ SwiftUI app for deliberate conversation capture.
It is optimized for 1:1s, interviews, and short decision-heavy conversations.
The standout feature is source-linked summaries: every decision, action item, or open question should be able to point back to transcript evidence.
The transcript is the source of truth. AI output is reviewable interpretation.

## Platform and stack
- iOS 26+
- SwiftUI
- SwiftData for metadata only
- File-backed storage for audio/transcript/summary artifacts
- SpeechAnalyzer + SpeechTranscriber for transcription
- Foundation Models for on-device summarization
- App Intents for system integration
- Accessibility is a release requirement

## Product rules
- Do not broaden scope into team collaboration, chat, cloud sync, or social features
- Do not add a permanent tab bar
- Record is a task flow, not a root destination
- Keep the UI calm, native, text-first, and Apple-like
- Do not add flashy AI visuals, oversized waveforms, glassmorphism, or novelty animations
- Every important AI-generated item must be source-linkable
- Transcript-first fallback must remain useful if summaries are unavailable

## Engineering rules
- Always propose a plan before large edits
- Work in small vertical slices
- Prefer native APIs and simple architecture
- Keep files focused and modular
- Do not invent APIs
- Do not stub fake functionality without clearly marking it
- Do not silently ignore errors
- Preserve testability
- Add or update tests for non-trivial logic
- Compile after each meaningful step
- Fix warnings/errors before moving on where practical
- Ensure cross-platform compatibility (use `#if os(iOS)` for iOS-specific SwiftUI modifiers like `bottomBar` or `navigationBarTitleDisplayMode`).
- Do not use scripts to explicitly add new files to the Xcode `project.pbxproj` file as Xcode automatically handles folder-based file inclusion (to avoid "duplicate build file" errors).
- Always verify you have `import SwiftData` or other required module imports when using their APIs.

## Accessibility rules
- VoiceOver must support common tasks
- Voice Control must support common tasks
- Larger Text must not break layout
- Reduce Motion must be respected
- Decorative elements should be hidden from accessibility
- Use standard controls unless a custom control is clearly justified

## Safety rules
- Never run destructive shell commands without explicit approval
- Never delete files outside the current project without explicit approval
- Never overwrite large sections of the codebase without summarizing the changes first
- Never enable unattended “turbo” style destructive actions
- Prefer reviewable diffs over broad autonomous refactors

## Build workflow
For each task:
1. Restate the exact goal
2. List files to create/change
3. Explain the approach briefly
4. Implement only the requested slice
5. Compile/test
6. Summarize what changed, what remains, and any risks
