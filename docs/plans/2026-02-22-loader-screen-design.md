# Loader Screen Design

## Summary
Full-screen splash with app icon and theme-matching gradient background. Shows during service preloading (min 1.5s).

## Visual
- **Day (5-21h):** headerDarkBrown → headerMidBrown → headerLightBrown gradient
- **Night (21-5h):** headerDarkNavy → headerMidNavy → headerLightNavy gradient
- **App Icon:** centered, fade-in + scale (0.8→1.0, ~0.6s spring)
- **Transition out:** fade-out ~0.5s when loaded

## Architecture
- `LoaderView` overlays `RootView` in `ReveriAIApp` ZStack
- `RootView` mounted from start (SwiftData + @State ready under loader)
- `@State isLoaded` in `ReveriAIApp` controls visibility
- `.task` modifier runs preloading + min 1.5s delay

## Preloading
1. Supabase client initialization (`SupabaseService.shared`)
2. Min 1.5s display time (parallel with services)

## Files
| File | Action |
|------|--------|
| `ReveriAI/Features/Loader/LoaderView.swift` | New |
| `ReveriAI/ReveriAIApp.swift` | Edit — add isLoaded state, ZStack, .task |
