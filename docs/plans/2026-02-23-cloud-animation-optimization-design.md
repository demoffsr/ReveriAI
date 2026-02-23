# Cloud Animation Optimization Design

**Date:** 2026-02-23
**Status:** Approved
**Scope:** RecordView cloud open/close animation performance

## Problem

Cloud expand/collapse animation on RecordView (triggered by `isTextFocused`) is noticeably sluggish in both directions. Root causes identified through profiling analysis:

1. **4 separate `.animation()` modifiers** on same trigger value create independent animation transactions
2. **Conflicting animation timings** — `headerContentVisible` opacity animates at 100ms while structural changes animate at 450ms
3. **DreamHeader Metal texture re-creation** — `.drawingGroup()` re-renders 1.3MB image + gradient + 50 stars Canvas on every frame during height animation (220pt -> 48pt = ~27 frames)
4. **CloudSeparator 3-layer re-composition** — 3 complex Bezier Shape layers composite without caching (~45 path computations x ~27 frames)
5. **closingClouds frame instability** — frame height depends on animated value, triggers VStack relayout + CloudClosedShape path recalculation every frame

## Approach: Targeted Fixes (Approach A)

Minimal code changes, maximum performance impact. No visual changes to the animation.

## Changes

### 1. Single animation transaction

**Before:** 4x `.animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)` on `contentArea`, `headerGradientBackground`, `headerTitle`, `cloudLayer`.

**After:** Remove all 4 `.animation()` modifiers. Wrap every `isTextFocused` mutation in `withAnimation(.spring(duration: 0.45, bounce: 0.0))`:
- `modeSwitchPill` button action (text mode toggle)
- `startTextModeTrigger` onChange handler
- Keyboard "Done" button

One transaction = all views animate synchronously.

### 2. Remove headerContentVisible state

**Before:** Separate `@State headerContentVisible` + `onChange(of: isTextFocused)` with `withAnimation(.easeOut(duration: 0.1))`. Creates timing conflict (100ms vs 450ms).

**After:** Delete `headerContentVisible` entirely. Replace `headerContentVisible ? 1 : 0` with `isTextFocused ? 0 : 1` everywhere. Delete the `onChange(of: isTextFocused)` block (lines 127-136). Opacity now animates with the same 0.45s spring as everything else.

### 3. DreamHeader fixed size with offset

**Before:** `DreamHeader().frame(height: headerHeight + cloudOverhang - 8)` where `headerHeight` animates. `.drawingGroup()` recreates Metal texture every frame.

**After:** Fixed `frame(height: baseHeaderHeight + cloudOverhang - 8)`. Animate `.offset(y:)` to slide header up. `.clipped()` hides overflow. Metal texture renders once, moves as unit.

### 4. drawingGroup on CloudSeparator

**Before:** ZStack of 3 Shapes without caching — 3 path computations + compositing per frame.

**After:** Add `.drawingGroup()` to CloudSeparator. 3 layers render into single Metal texture. Opacity animates on texture — one operation instead of three.

### 5. closingClouds fixed frame

**Before:** `.frame(height: headerHeight + cloudOverhang)` — height animates, VStack relayouts, `CloudClosedShape.path(in:)` recalculates each frame.

**After:** Fixed `.frame(height: baseHeaderHeight + cloudOverhang)`. Visibility controlled only via offset (unchanged). Shape size stable — path computed once.

## Files Changed

| File | Changes |
|------|---------|
| `ReveriAI/Features/Record/RecordView.swift` | Remove 4x `.animation()`, remove `headerContentVisible`, add `withAnimation` at trigger points, fix DreamHeader frame, fix closingClouds frame |
| `ReveriAI/Components/Clouds/CloudSeparator.swift` | Add `.drawingGroup()` |

## Risks & Rollback

- **Risk:** Low — same animation parameters (spring 0.45s, bounce 0.0), same visual targets (offset, opacity values unchanged)
- **Rollback:** Simple git revert of 2 files
