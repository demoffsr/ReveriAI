# Secrets Management Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Migrate Supabase API keys from hardcoded values to Xcconfig-based configuration for secure, git-ignored secrets management.

**Architecture:** Use Xcode configuration files (.xcconfig) to store secrets locally, inject them into Info.plist at build time, and read them from Bundle at runtime. This follows iOS industry standards and prevents secrets from being committed to Git.

**Tech Stack:** Xcode Build System, xcconfig files, Info.plist substitution, Bundle.main.infoDictionary

---

## Task 1: Create .gitignore

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore with iOS standard exclusions**

Create `.gitignore` in project root with the following content:

```gitignore
# Secrets
Secrets.xcconfig

# Xcode
*.xcuserdata
*.xcuserdatad
xcuserdata/
DerivedData/
*.xcworkspace/xcuserdata/
*.xcodeproj/xcuserdata/
*.xcodeproj/project.xcworkspace/xcuserdata/

# Build artifacts
build/
*.ipa
*.dSYM.zip
*.dSYM

# Swift Package Manager
.swiftpm/
*.swiftpm
Packages/
.build/

# macOS
.DS_Store
.AppleDouble
.LSOverride

# Fastlane
fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots
fastlane/test_output
```

**Step 2: Verify .gitignore is working**

Run:
```bash
git status
```

Expected: `.gitignore` appears as untracked file. `xcuserdata/` and `.DS_Store` should NOT appear in untracked files list.

**Step 3: Commit .gitignore**

Run:
```bash
git add .gitignore
git commit -m "Add iOS .gitignore

Exclude Secrets.xcconfig, Xcode user data, build artifacts, and macOS files.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

Expected: Commit successful, SHA displayed.

---

## Task 2: Create Secrets.xcconfig

**Files:**
- Create: `Secrets.xcconfig`

**Step 1: Create Secrets.xcconfig with current Supabase keys**

Create `Secrets.xcconfig` in project root:

```
// Supabase Configuration
SUPABASE_PROJECT_URL = https:/​/bvydopjjndfgbhjczyis.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ2eWRvcGpqbmRmZ2JoamN6eWlzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEwOTc3MTAsImV4cCI6MjA4NjY3MzcxMH0.7gx8RcEnJSHjMAjUQ5YJLMGZrHpbH4Jp5FlMgS_XE20
```

**Step 2: Verify Secrets.xcconfig is git-ignored**

Run:
```bash
git status
```

Expected: `Secrets.xcconfig` does NOT appear in untracked files (because it's in .gitignore).

---

## Task 3: Link Xcconfig to Xcode Project

**Files:**
- Modify: `ReveriAI.xcodeproj/project.pbxproj` (via Xcode UI)

**Step 1: Open project in Xcode**

Run:
```bash
open ReveriAI.xcodeproj
```

**Step 2: Configure Debug configuration**

1. In Xcode, select project root "ReveriAI" in navigator
2. Select "ReveriAI" project (not target) in editor
3. Go to "Info" tab
4. Under "Configurations", expand "Debug"
5. For "ReveriAI" target, click dropdown and select "Secrets"
6. Click "+" button if "Secrets" doesn't exist:
   - Click "+" → "Add Configuration File"
   - Navigate to `Secrets.xcconfig`
   - Select it

**Step 3: Configure Release configuration**

Repeat Step 2 for "Release" configuration.

**Step 4: Verify xcconfig is linked**

In Xcode Project Info tab, both Debug and Release should show "Secrets" for ReveriAI target.

**Step 5: Save Xcode project**

Run: Cmd+S in Xcode

---

## Task 4: Test Build with Xcconfig

**Files:**
- None (verification step)

**Step 1: Clean build folder**

In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

Or via command line:
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/ReveriAI-*
```

**Step 2: Build project**

Run:
```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

**Step 3: Verify xcconfig is loaded**

Check build log for references to SUPABASE variables. If build succeeds, xcconfig is loaded correctly.

---

## Task 5: Update Info.plist

**Files:**
- Modify: `ReveriAI/Info.plist`

**Step 1: Open Info.plist in Xcode**

1. In Xcode navigator, find `ReveriAI/Info.plist`
2. Right-click → "Open As" → "Source Code"

**Step 2: Add Supabase configuration keys**

Add these two entries before the closing `</dict>` tag:

```xml
	<key>SUPABASE_PROJECT_URL</key>
	<string>$(SUPABASE_PROJECT_URL)</string>
	<key>SUPABASE_ANON_KEY</key>
	<string>$(SUPABASE_ANON_KEY)</string>
```

**Step 3: Save Info.plist**

Cmd+S in Xcode

**Step 4: Verify placeholder syntax**

Open `ReveriAI/Info.plist` and confirm both keys use `$(VARIABLE_NAME)` syntax, NOT hardcoded values.

---

## Task 6: Test Build with Info.plist

**Files:**
- None (verification step)

**Step 1: Clean build folder**

In Xcode: Product → Clean Build Folder (Cmd+Shift+K)

**Step 2: Build project**

Run:
```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Expected: `** BUILD SUCCEEDED **`

If build fails with "Missing SUPABASE_*" error, xcconfig is not linked properly. Go back to Task 3.

---

## Task 7: Update SupabaseConfig.swift

**Files:**
- Modify: `ReveriAI/Config/SupabaseConfig.swift`

**Step 1: Read current file**

Current content (hardcoded keys):
```swift
enum SupabaseConfig {
    static let projectURL = "https://bvydopjjndfgbhjczyis.supabase.co"
    static let anonKey = "eyJhbGci..."
}
```

**Step 2: Replace with Bundle reads**

Replace entire file content with:

```swift
import Foundation

enum SupabaseConfig {
    static let projectURL: String = {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_PROJECT_URL"] as? String,
              !url.isEmpty,
              !url.hasPrefix("$(") else {
            fatalError("Missing or invalid SUPABASE_PROJECT_URL in Info.plist. Ensure Secrets.xcconfig is configured.")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else {
            fatalError("Missing or invalid SUPABASE_ANON_KEY in Info.plist. Ensure Secrets.xcconfig is configured.")
        }
        return key
    }()
}
```

**Step 3: Save file**

Cmd+S in Xcode

**Step 4: Verify no hardcoded secrets remain**

Run:
```bash
grep -n "eyJ" ReveriAI/Config/SupabaseConfig.swift
```

Expected: No output (grep finds nothing).

---

## Task 8: Test Runtime

**Files:**
- None (verification step)

**Step 1: Build and run app**

In Xcode: Product → Run (Cmd+R)

Or via command line:
```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
open -a Simulator
# Wait for simulator to boot
xcrun simctl install booted <path-to-built-app>
xcrun simctl launch booted com.yourcompany.ReveriAI
```

**Step 2: Verify app launches without crash**

Expected: App launches normally, no fatalError about missing keys.

**Step 3: Test Supabase connection**

In the app:
1. Record a dream (voice or text)
2. Save the dream
3. Wait ~2 seconds for AI title generation

Expected: Dream title appears (confirms Supabase connection works).

**Step 4: Check Xcode console for errors**

Expected: No "Missing SUPABASE_*" errors in console.

---

## Task 9: Commit Changes

**Files:**
- Modify: `ReveriAI/Config/SupabaseConfig.swift`
- Modify: `ReveriAI/Info.plist`
- Modify: `ReveriAI.xcodeproj/project.pbxproj`

**Step 1: Verify Secrets.xcconfig is NOT staged**

Run:
```bash
git status
```

Expected: `Secrets.xcconfig` should NOT appear in "Changes to be committed" or "Untracked files" (it's git-ignored).

**Step 2: Stage migration files**

Run:
```bash
git add ReveriAI/Config/SupabaseConfig.swift
git add ReveriAI/Info.plist
git add ReveriAI.xcodeproj/project.pbxproj
```

**Step 3: Verify diff**

Run:
```bash
git diff --cached
```

Expected:
- `SupabaseConfig.swift`: hardcoded keys removed, Bundle reads added
- `Info.plist`: two new keys with `$(...)` placeholders
- `project.pbxproj`: xcconfig references added

Verify NO hardcoded secrets appear in diff.

**Step 4: Commit migration**

Run:
```bash
git commit -m "$(cat <<'EOF'
Migrate to Xcconfig-based secrets management

- Move Supabase keys from hardcoded values to Secrets.xcconfig
- Update SupabaseConfig to read from Bundle.main.infoDictionary
- Add Info.plist placeholders for build-time substitution
- Link Secrets.xcconfig to Debug/Release configurations

Secrets.xcconfig is git-ignored and must be created locally.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>
EOF
)"
```

Expected: Commit successful with changes to 3 files.

**Step 5: Verify clean working tree**

Run:
```bash
git status
```

Expected: "nothing to commit, working tree clean"

---

## Rollback Plan (If Needed)

If migration causes issues, rollback with:

```bash
git restore ReveriAI/Config/SupabaseConfig.swift
git restore ReveriAI/Info.plist
git restore ReveriAI.xcodeproj/project.pbxproj
```

Then in Xcode:
1. Project Settings → Info → Configurations
2. Set Debug/Release to "None" for xcconfig

Build will work with Git-committed hardcoded keys.

---

## Post-Migration Checklist

- [ ] `.gitignore` committed and working
- [ ] `Secrets.xcconfig` created locally (NOT in Git)
- [ ] Xcconfig linked to Debug/Release configurations
- [ ] Info.plist has placeholder variables
- [ ] SupabaseConfig reads from Bundle
- [ ] App builds successfully
- [ ] App runs and Supabase connection works
- [ ] No hardcoded secrets in Git history (check `git log -p`)
- [ ] Migration committed to Git

---

## Testing Strategy

**Build-time verification:**
- Clean build succeeds on both Debug and Release
- xcconfig variables are substituted in Info.plist

**Runtime verification:**
- App launches without fatalError
- Supabase API calls succeed (test with dream save + AI title generation)
- Keys are loaded correctly (can add debug print in SupabaseConfig if needed)

**Security verification:**
- `git status` never shows `Secrets.xcconfig`
- `git log --all -p | grep "eyJ"` only shows old commits (before migration)
- New commits have NO hardcoded secrets
