# Cloud Animation Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate jank in RecordView cloud open/close animation by reducing render overhead and synchronizing animation transactions.

**Architecture:** Replace 4 independent `.animation()` modifiers with unified `withAnimation` at trigger points. Remove conflicting `headerContentVisible` state. Fix DreamHeader to use fixed-size Metal texture with offset instead of frame resize. Add `.drawingGroup()` to CloudSeparator. Stabilize closingClouds frame.

**Tech Stack:** SwiftUI, Metal (via `.drawingGroup()`)

---

### Task 1: Remove `.animation()` modifiers and add `withAnimation` at trigger points

**Files:**
- Modify: `ReveriAI/Features/Record/RecordView.swift`

**Step 1: Remove 4x `.animation(value: isTextFocused)` from body**

Replace lines 82-97 in `body`:

```swift
                // Layer 1: Content (below header + cloud zone)
                contentArea
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)

                // Layer 2: Header gradient background (animated)
                headerGradientBackground
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)

                // Layer 3: Title + icon (shifts up slightly when keyboard appears)
                headerTitle
                    .offset(y: isTextFocused ? -25 : 0)
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)

                // Layer 4: Clouds + pill (animated, on top of title)
                cloudLayer
                    .animation(.spring(duration: 0.45, bounce: 0.0), value: isTextFocused)
```

With:

```swift
                // Layer 1: Content (below header + cloud zone)
                contentArea

                // Layer 2: Header gradient background (animated)
                headerGradientBackground

                // Layer 3: Title + icon (shifts up slightly when keyboard appears)
                headerTitle
                    .offset(y: isTextFocused ? -25 : 0)

                // Layer 4: Clouds + pill (animated, on top of title)
                cloudLayer
```

**Step 2: Wrap all `isTextFocused` mutations in `withAnimation`**

There are 5 mutation sites. Wrap each one:

**Site 1** — `startTextModeTrigger` onChange (line 148):
```swift
// Before:
isTextFocused = true

// After:
withAnimation(.spring(duration: 0.45, bounce: 0.0)) {
    isTextFocused = true
}
```

**Site 2** — SaveDreamButton in cloudLayer overlay (line 232):
```swift
// Before:
isTextFocused = false

// After:
withAnimation(.spring(duration: 0.45, bounce: 0.0)) {
    isTextFocused = false
}
```

**Site 3** — modeSwitchPill button, voice->text (line 286):
```swift
// Before:
isTextFocused = true

// After:
withAnimation(.spring(duration: 0.45, bounce: 0.0)) {
    isTextFocused = true
}
```

**Site 4** — modeSwitchPill button, text->voice (line 288):
```swift
// Before:
isTextFocused = false

// After:
withAnimation(.spring(duration: 0.45, bounce: 0.0)) {
    isTextFocused = false
}
```

**Site 5** — Keyboard "Done" button (line 405):
```swift
// Before:
isTextFocused = false

// After:
withAnimation(.spring(duration: 0.45, bounce: 0.0)) {
    isTextFocused = false
}
```

**Step 3: Build and verify**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 4: Commit**

```bash
git add ReveriAI/Features/Record/RecordView.swift
git commit -m "perf: replace 4x .animation() with unified withAnimation for cloud animation"
```

---

### Task 2: Remove `headerContentVisible` state

**Files:**
- Modify: `ReveriAI/Features/Record/RecordView.swift`

**Step 1: Delete `headerContentVisible` state declaration**

Remove line 22:
```swift
@State private var headerContentVisible: Bool = true
```

**Step 2: Delete `onChange(of: isTextFocused)` block**

Remove lines 127-137:
```swift
        .onChange(of: isTextFocused) { _, focused in
            if focused {
                withAnimation(.easeOut(duration: 0.1)) {
                    headerContentVisible = false
                }
            } else {
                withAnimation(.easeOut(duration: 0.1)) {
                    headerContentVisible = true
                }
            }
        }
```

**Step 3: Replace `headerContentVisible` with `isTextFocused` in opacity expressions**

3 locations:

**headerGradientBackground** (line 158):
```swift
// Before:
.opacity(headerContentVisible ? 1 : 0)

// After:
.opacity(isTextFocused ? 0 : 1)
```

**headerTitle** (line 199):
```swift
// Before:
.opacity(headerContentVisible ? 1 : 0)

// After:
.opacity(isTextFocused ? 0 : 1)
```

**CloudSeparator in cloudLayer** (line 211):
```swift
// Before:
.opacity(headerContentVisible ? 1 : 0)

// After:
.opacity(isTextFocused ? 0 : 1)
```

**Step 4: Build and verify**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 5: Commit**

```bash
git add ReveriAI/Features/Record/RecordView.swift
git commit -m "perf: remove headerContentVisible, use isTextFocused directly for opacity"
```

---

### Task 3: Fix DreamHeader to use fixed size + offset

**Files:**
- Modify: `ReveriAI/Features/Record/RecordView.swift`

**Step 1: Change headerGradientBackground to fixed height with offset**

Replace `headerGradientBackground` computed property:

```swift
// Before:
private var headerGradientBackground: some View {
    DreamHeader()
        .frame(height: headerHeight + cloudOverhang - 8)
        .clipped()
        .opacity(isTextFocused ? 0 : 1)
}

// After:
private var headerGradientBackground: some View {
    DreamHeader()
        .frame(height: baseHeaderHeight + cloudOverhang - 8)
        .offset(y: isTextFocused ? -(baseHeaderHeight - baseHeaderHeight * 0.22) : 0)
        .clipped()
        .opacity(isTextFocused ? 0 : 1)
}
```

Note: `baseHeaderHeight * 0.22` = 48.4 (the collapsed headerHeight). The offset shifts up by the difference (220 - 48.4 = 171.6pt) so the clipped region matches the previous animated frame behavior.

**Step 2: Build and verify**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add ReveriAI/Features/Record/RecordView.swift
git commit -m "perf: fix DreamHeader to static frame size, animate offset instead"
```

---

### Task 4: Add `.drawingGroup()` to CloudSeparator

**Files:**
- Modify: `ReveriAI/Components/Clouds/CloudSeparator.swift`

**Step 1: Add `.drawingGroup()` to the ZStack**

Replace entire file:

```swift
import SwiftUI

struct CloudSeparator: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            CloudBackShape()
                .fill(theme.cloudBack)
            CloudMidShape()
                .fill(theme.cloudMid)
            CloudFrontShape()
                .fill(theme.cloudFront)
        }
        .drawingGroup()
    }
}
```

**Step 2: Build and verify**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add ReveriAI/Components/Clouds/CloudSeparator.swift
git commit -m "perf: add drawingGroup to CloudSeparator for Metal texture caching"
```

---

### Task 5: Fix closingClouds to use fixed frame

**Files:**
- Modify: `ReveriAI/Features/Record/RecordView.swift`

**Step 1: Replace animated frame with fixed frame**

In `closingClouds` computed property, change line 172:

```swift
// Before:
.frame(height: headerHeight + cloudOverhang)

// After:
.frame(height: baseHeaderHeight + cloudOverhang)
```

The offset on line 173 (`isTextFocused ? 0 : -(baseHeaderHeight + cloudOverhang)`) already uses `baseHeaderHeight` — no change needed there.

**Step 2: Build and verify**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 3: Commit**

```bash
git add ReveriAI/Features/Record/RecordView.swift
git commit -m "perf: fix closingClouds to static frame, prevent path recalculation"
```

---

### Task 6: Final build verification

**Step 1: Full clean build**

Run: `xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' clean build 2>&1 | tail -5`
Expected: `BUILD SUCCEEDED`

**Step 2: Verify no references to `headerContentVisible` remain**

Run: `grep -r "headerContentVisible" ReveriAI/`
Expected: No output (zero matches)

**Step 3: Verify no `.animation(value: isTextFocused)` remain**

Run: `grep -n "animation.*isTextFocused" ReveriAI/Features/Record/RecordView.swift`
Expected: No output (zero matches)
