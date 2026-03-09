# ADR 0017: Split InputPanelController into focused services

## Status

Accepted

## Context

InputPanelController had grown to 849 lines and accumulated 5 distinct responsibilities: replacement rule management, script execution, voice input coordination, panel lifecycle management, and orchestration. This made it difficult to unit test individual concerns and increased the cognitive load of working with the file.

## Considered Options

- **A: Extract services with TextViewOperating protocol** — Create focused service classes with a protocol abstraction for NSTextView access, enabling mock-based unit testing.
- **B: Extract services with closure-based textView access** — Pass textView operations as closures to each service. Avoids a protocol but results in 10+ closure parameters per service.
- **C: Keep as single file with MARK sections** — No structural change; rely on code folding and discipline.

## Decision

We will adopt Option A: extract four services (ReplacementService, ScriptExecutionService, VoiceInputCoordinator, PanelLifecycleManager) with a shared TextViewOperating protocol. InputPanelController remains as a thin coordinator (~430 lines) responsible for init wiring, confirm/cancel orchestration, and callback dispatch.

Key design choices:
- All services are `@MainActor` (required by VoiceInputDelegate/VoiceInputEngine protocols)
- voiceInsertionPoint is owned by VoiceInputCoordinator; other services access it via closures
- textView is distributed to each service via `onTextViewCreated` callback
- Forward methods and computed properties on the coordinator maintain backward-compatible API for existing integration tests

## Consequences

- **Positive**: Each service is independently unit-testable with mock TextViewOperating. 49 new unit tests added. Cognitive load reduced when working on a single concern.
- **Positive**: Clear ownership of state — replay suppression lives in VoiceInputCoordinator, replacement previews in ReplacementService, script running state in ScriptExecutionService.
- **Negative**: textView reference is stored in 4 places (coordinator + 3 services), requiring synchronized setup in onTextViewCreated.
- **Negative**: Coordinator is ~430 lines rather than the planned ~250, primarily due to confirm() orchestration and init callback wiring that must remain centralized.
- **Neutral**: Existing InputPanelControllerTests continue to serve as integration tests unchanged.
