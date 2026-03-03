# CLAUDE.md Refactor Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Split monolithic CLAUDE.md (~16KB, always in context) into a concise core + topic files loaded on demand.

**Architecture:** CLAUDE.md keeps only always-needed info (build, arch, critical conventions). Component patterns, AI services, and performance details move to `docs/claude/` files that Claude reads only when working on those topics.

**Tech Stack:** Markdown files only. No code changes.

---

### Task 1: Create `docs/claude/patterns.md`

**Files:**
- Create: `docs/claude/patterns.md`

**Step 1: Create the file with all component patterns from CLAUDE.md**

Content: Move the entire "Key Patterns" section from CLAUDE.md into this file.
Include: Cloud system, CelestialIcon, Header layout, Mode switch pill, Save Dream button, Text input, Tab bar, Tab switching, Recording state machine, Voice→text flow, Recording mode, Review mode, Audio recording, Speech recognition, Punctuation post-processing, Locale picker, Live captions, Audio waveform, EmotionTagBadge, DreamCard, DreamDetailView, Folders system, Card waveform player, Press feedback, Toast system, Keyboard Done button, Liquid Glass style, Journal header, Emotion filter bar, Emotion filter→tab bar, Journal filtering performance, Emotion picker flow (post-save), DetailDreamState, EmotionPickerGrid, Dream Reminder, Profile screen, NotificationService, URL scheme deep links, Assets.

File header:
```markdown
# ReveriAI — Component Patterns

Reference for UI components, state machines, and architectural patterns.
Load this file when working on any UI component, recording flow, or navigation.

---
```

**Step 2: Commit**
```bash
git add docs/claude/patterns.md
git commit -m "docs: add component patterns reference file"
```

---

### Task 2: Create `docs/claude/ai-services.md`

**Files:**
- Create: `docs/claude/ai-services.md`

**Step 1: Create the file with AI integration details**

Content: Move these sections from CLAUDE.md "Key Patterns":
- AI title generation
- AI image generation
- AI dream interpretation

File header:
```markdown
# ReveriAI — AI Services

Reference for Supabase Edge Functions, OpenAI integration, and AI pipelines.
Load this file when working on AI features, edge functions, or Supabase integration.

**Deploy edge functions:**
`~/bin/supabase functions deploy <name> --project-ref bvydopjjndfgbhjczyis`

---
```

**Step 2: Commit**
```bash
git add docs/claude/ai-services.md
git commit -m "docs: add AI services reference file"
```

---

### Task 3: Create `docs/claude/performance.md`

**Files:**
- Create: `docs/claude/performance.md`

**Step 1: Create the file with performance patterns**

Content: Move the entire "Performance Optimizations" section from CLAUDE.md.
Also move these conventions from CLAUDE.md "Conventions" (they're performance-specific, not always needed):
- Canvas performance (`WaveformBuffer` pattern)
- Performance patterns (cache, debounce, drawingGroup, etc.)

File header:
```markdown
# ReveriAI — Performance Patterns

Reference for caching strategies, rendering optimizations, and memory management.
Load this file when optimizing performance, adding new cached state, or working with Canvas/waveform.

---
```

**Step 2: Commit**
```bash
git add docs/claude/performance.md
git commit -m "docs: add performance patterns reference file"
```

---

### Task 4: Rewrite CLAUDE.md to be concise

**Files:**
- Modify: `CLAUDE.md`

**Step 1: Replace CLAUDE.md with the concise version**

Keep:
- Language
- Build
- Secrets Management (full — critical for new environments)
- Architecture (condensed to bullet points, no expansion)
- Project Structure (keep as-is — useful at-a-glance reference)
- Conventions (keep only always-needed gotchas):
  - Glass effect rule (`.reveriGlass` — used everywhere)
  - Glass in toolbar bug
  - Tab switching (no `.opacity()` — ghosting gotcha)
  - Text concatenation iOS 26 (deprecated `Text + Text`)
  - Swift 6 + `@unchecked Sendable` / `nonisolated`
  - TimelineView + @State timing (optionals, not 0)
  - Observation isolation pattern (LiveWaveformView)
  - Complex view type-check fix
  - Figma scale (~1.6×)
  - Views thin, logic in ViewModels

Add at bottom:
```markdown
## Detailed References

Load these files when working on the relevant area:

- `docs/claude/patterns.md` — UI components, state machines, recording flow, navigation
- `docs/claude/ai-services.md` — AI title/image/interpretation, Supabase edge functions
- `docs/claude/performance.md` — caching strategies, Canvas/waveform optimizations
```

Remove from CLAUDE.md:
- All of "Key Patterns" section (→ patterns.md)
- All of "Performance Optimizations" section (→ performance.md)
- "Canvas performance" and "Performance patterns" from Conventions (→ performance.md)

**Step 2: Commit**
```bash
git add CLAUDE.md
git commit -m "docs: refactor CLAUDE.md — move patterns/AI/perf to docs/claude/"
```
