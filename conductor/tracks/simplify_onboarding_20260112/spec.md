# Specification - Simplify the Onboarding

## Overview
The goal of this track is to modernize the onboarding experience in SystemVoiceMemos. Currently, the onboarding is functional but lacks the "first-party" feel and friendly tone defined in our product guidelines. We will redesign the `OnboardingView` to be more engaging, clear, and helpful.

## Functional Requirements
- **Visual Redesign:** Update the UI to use native macOS components and SF Symbols, following Apple's Human Interface Guidelines.
- **Permission Clarity:** Provide distinct, visually appealing sections for "Screen Recording" and "Audio Input" permissions.
- **Interactive States:** Show real-time feedback (e.g., checkmarks or color changes) when a permission is granted.
- **Call to Action:** A clear "Get Started" button that only becomes active (or prominent) once essential permissions are handled.

## Non-Functional Requirements
- **Native Look & Feel:** Use standard SwiftUI `Label`, `GroupBox`, or `ContentUnavailableView` (if appropriate) to match macOS 15+ aesthetics.
- **Friendly Tone:** Rewrite labels and descriptions to be warm and encouraging.

## Acceptance Criteria
- Onboarding screen appears on first launch or when triggered manually via the Help menu.
- Both Screen Recording and Audio permissions are clearly explained with corresponding icons.
- Granting a permission provides immediate visual confirmation in the onboarding UI.
- The experience feels "native" and adheres to the SF Pro typography and system colors.
