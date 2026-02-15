# Secrets Management Design

**Date:** 2026-02-15
**Status:** Approved
**Approach:** Xcconfig-based secrets management

---

## Problem

Currently, Supabase API keys are hardcoded in `SupabaseConfig.swift` and committed to the public GitHub repository. While the `anon` key is public-safe by design (protected by Row Level Security), this is not best practice and poses risks if admin keys are accidentally added in the future.

**Current state:**
- No `.gitignore` file in project
- Supabase anon key hardcoded in `ReveriAI/Config/SupabaseConfig.swift:5`
- OpenAI API key is already secure (stored in Supabase Edge Function secrets)

---

## Solution: Xcconfig-based Configuration

### Architecture

**Build pipeline:**
```
Secrets.xcconfig (git-ignored)
    ↓
Xcode Build Settings
    ↓
Info.plist (build time substitution)
    ↓
Bundle.main.infoDictionary (runtime)
    ↓
SupabaseConfig.swift (reads from Bundle)
```

**How it works:**
1. Store secrets in `Secrets.xcconfig` as build variables
2. Xcode project references this xcconfig for Debug/Release configurations
3. `Info.plist` uses placeholder syntax: `$(VARIABLE_NAME)`
4. At build time, Xcode substitutes real values
5. Swift code reads values via `Bundle.main.infoDictionary`

**Benefits:**
- ✅ Industry standard for iOS secrets management
- ✅ Works seamlessly with Simulator/Device/Previews
- ✅ File is local-only, excluded from Git
- ✅ Easy to add more secrets in the future
- ✅ No runtime overhead

---

## File Structure

### New Files

**`Secrets.xcconfig`** (root directory, git-ignored):
```
SUPABASE_PROJECT_URL = https://bvydopjjndfgbhjczyis.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2eWRvcGpqbmRmZ2JoamN6eWlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwOTc3MTAsImV4cCI6MjA4NjY3MzcxMH0.7gx8RcEnJSHjMAjUQ5YJLMGZrHpbH4Jp5FlMgS_XE20
```

**`.gitignore`** (root directory):
Standard iOS gitignore including `Secrets.xcconfig`, xcuserdata, DerivedData, build artifacts, .DS_Store, etc.

### Modified Files

**`ReveriAI/Info.plist`**
Add two new keys:
```xml
<key>SUPABASE_PROJECT_URL</key>
<string>$(SUPABASE_PROJECT_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

**`ReveriAI/Config/SupabaseConfig.swift`**
Replace hardcoded values with Bundle reads:
```swift
enum SupabaseConfig {
    static let projectURL: String = {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_PROJECT_URL"] as? String else {
            fatalError("Missing SUPABASE_PROJECT_URL in Info.plist")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("Missing SUPABASE_ANON_KEY in Info.plist")
        }
        return key
    }()
}
```

---

## Migration Plan

**Safe migration steps (no breakage):**

1. Create `.gitignore` with standard iOS exclusions
2. Create `Secrets.xcconfig` with current Supabase keys
3. Configure Xcode project to use xcconfig for Debug/Release builds
4. Update `Info.plist` with placeholder variables
5. **Test build** — verify project compiles
6. Update `SupabaseConfig.swift` to read from Bundle
7. **Test runtime** — run app, verify keys are loaded correctly
8. Commit changes (excluding `Secrets.xcconfig` via .gitignore)

**Validation at each step:**
- After step 5: `xcodebuild -scheme ReveriAI build` should succeed
- After step 7: Launch app, verify Supabase connection works

---

## Rollback Plan

If migration causes issues:

```bash
# Restore original files
git restore ReveriAI/Config/SupabaseConfig.swift
git restore ReveriAI/Info.plist

# Remove Secrets.xcconfig reference from Xcode project
# (via Xcode UI: Project Settings → Configurations → set to "None")

# Build will work with old hardcoded key
```

---

## Gitignore Coverage

The `.gitignore` will exclude:
- **Secrets:** `Secrets.xcconfig`
- **Xcode user data:** `xcuserdata/`, `*.xcuserdatad`
- **Build artifacts:** `DerivedData/`, `build/`, `*.ipa`, `*.dSYM`
- **SPM cache:** `.swiftpm/`, `.build/`, `Packages/`
- **macOS files:** `.DS_Store`, `.AppleDouble`
- **Fastlane:** test output, screenshots, reports

This ensures:
- No secrets leak to Git
- Cleaner repository (no Xcode-generated files)
- Smaller clone size (no DerivedData)

---

## Security Posture After Migration

| Item | Before | After |
|------|--------|-------|
| Supabase anon key | ❌ Hardcoded in Git | ✅ Local-only file |
| OpenAI API key | ✅ Supabase Secrets | ✅ Supabase Secrets |
| .gitignore | ❌ Missing | ✅ Comprehensive iOS coverage |
| Future secrets | ⚠️ Would be hardcoded | ✅ Easy to add to xcconfig |

---

## Rejected Alternatives

### Alternative 1: Leave as-is
- **Pro:** No work, anon key is public-safe
- **Con:** Not best practice, risky if admin keys added later

### Alternative 2: Environment variables via Run Script
- **Pro:** More flexible for multiple environments
- **Con:** More complex, may break Xcode Previews

**Chosen approach (Xcconfig) is the iOS industry standard and best balance of security, simplicity, and maintainability.**
