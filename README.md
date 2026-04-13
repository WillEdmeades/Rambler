# Rambler

Rambler is an iPhone SwiftUI app for recording short conversations and turning them into grounded review notes.

It is built for 1:1s, interviews, and other decision-heavy conversations where the transcript should stay more important than the summary.

For a quick technical overview, see [ARCHITECTURE.md](ARCHITECTURE.md).

## What The App Does

- Records audio and transcribes it on device
- Turns a session into structured review notes, bullet summaries, and follow-up items
- Keeps generated notes tied back to transcript evidence where possible
- Lets you search, correct, bookmark, and play back transcript sections
- Exports full sessions, notes, actions, JSON, and audio
- Integrates with system features like Shortcuts, Spotlight, Live Activities, and widgets

## Why I Built It

Most conversation tools drift too far in one direction.

Some give you a raw transcript and leave all the work to you.
Others give you a polished AI summary that quietly becomes the record.

Rambler is meant to sit in the middle. The transcript stays canonical, and the summary is only useful if it can be reviewed against the source.

## What This Repo Covers

- A focused iOS app with a narrow product scope
- On-device recording, transcription, and summarization
- A transcript-first review flow instead of a chat-style AI interface
- A feature-first SwiftUI codebase with lightweight services and view models

## Tech Stack

- SwiftUI
- Observation
- SwiftData for lightweight metadata
- File-backed storage for audio, transcript, and summary artifacts
- `AVAudioEngine` and `AVAudioFile`
- `SpeechAnalyzer` and `SpeechTranscriber`
- Foundation Models
- App Intents, Core Spotlight, ActivityKit, and WidgetKit

## Product Scope

- Built for short, deliberate conversations
- Keeps everything on device
- Does not try to become chat, collaboration, or cloud notes
- Treats recording as a task flow, not a permanent root destination
- Keeps transcript review useful even when summary generation is unavailable

## Project Structure

```text
Rambler/
├── Rambler/
│   ├── Core/        # models, persistence, shared services
│   ├── Features/    # recording, session detail, settings
│   ├── Shared/      # shared UI support and utilities
│   └── System/      # App Intents and platform integration
└── RamblerTests/    # focused logic tests
```

## Running The App

Requirements:

- Xcode 26.2+
- iOS 26.2 simulator or device

Steps:

1. Open `Rambler.xcodeproj`
2. Run the `Rambler` scheme
3. Grant microphone and speech permissions
4. Record a short conversation and open the saved session to review it

## Notes

- Rambler is designed for iPhone first and is now iOS-only
- Summary quality depends on Foundation Models availability in the runtime environment
- The quickest way to understand the app is to record something short, generate notes, and jump from one generated item back into the transcript
