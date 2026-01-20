# Initial Concept
SystemVoiceMemos is a macOS utility for capturing system audio using ScreenCaptureKit, persisting recordings with metadata via SwiftData, and providing a modern SwiftUI interface for management and playback.

# Product Guide - SystemVoiceMemos

## Overview
SystemVoiceMemos is a privacy-first macOS utility designed for creators, developers, and casual users who need to capture system audio with minimal friction. It focuses on local-only processing, high performance, and a minimalist user experience.

## Target Audience
- **Content Creators & Podcasters:** For capturing high-quality audio from system sources for further production.
- **Developers & Testers:** For documenting audio-related behavior or bugs in other software.
- **Casual Users:** For saving snippets of important calls, videos, or system sounds for personal reference.

## Core Goals
- **Seamless Capture:** A one-click recording experience that stays out of the way.
- **Efficient Organization:** Robust metadata management using SwiftData to keep recordings organized and searchable.
- **Low Impact:** High-performance capture using ScreenCaptureKit with minimal system resource usage.

## Functional Requirements
- **Audio Export:** Support for exporting recordings in various formats including MP3 and WAV.
- **Visual Feedback:** Improved real-time waveform visualization and audio level monitoring.
- **Guided Onboarding:** A clear, dedicated flow on first launch to handle macOS Screen Recording and Audio permissions.

## Non-Functional Requirements & Constraints
- **Privacy First:** All recording and processing must happen locally; data never leaves the user's machine.
- **Minimalist Design:** A clean SwiftUI interface with a focus on quick access, including a planned Menubar mode.
