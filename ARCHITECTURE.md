# Rambler Architecture

Rambler keeps the architecture intentionally small.

The app records a conversation, stores the raw artifacts locally, and builds the review experience around the transcript. The transcript is the source of truth. Everything else is interpretation layered on top.

## Core Idea

- SwiftData stores lightweight session metadata
- Audio, transcript, and summary artifacts live on disk
- Summary output is generated from transcript chunks and kept source-linked where possible
- The UI follows the real task flow: list, preflight, capture, review, export

## Main Flow

- `SessionsListView` is the root screen and archive
- `PreflightView` handles title, locale, and readiness checks before recording
- `ActiveRecordingViewModel` coordinates capture, live transcription, bookmarks, and final save
- `SessionDetailViewModel` handles playback, transcript review, summaries, and export
- `ExportService` creates focused export outputs instead of generic dump formats

## Persistence

- `Recording` in SwiftData stores metadata like title, date, duration, pin state, bookmark timestamps, and artifact filenames
- `StorageService` manages transcript JSON, summary JSON, and audio files
- `SessionRepository` keeps metadata and file-backed artifacts in sync

## Summary Pipeline

- `TranscriptChunker` breaks long transcripts into manageable chunks
- `SummaryService` uses Foundation Models to produce structured notes
- Generated items are validated against real transcript segment IDs before they are kept
- The app still has a usable transcript-first review path when summaries are unavailable

## Project Structure

- `Core` holds models, persistence, and shared services
- `Features` is organized by user-facing flows like recording and session detail
- `Shared` contains reusable support code
- `System` holds platform integration such as App Intents
- `RamblerTests` covers focused logic around chunking, storage, export, and review behavior

## Notes

- iPhone-first and iOS-only
- Privacy-first and on-device by default
- Intentionally out of scope: chat UI, collaboration, cloud sync, and social features
