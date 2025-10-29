# Fix: "Cannot preview in this file" Error

## The Problem
Xcode says: "Cannot preview in this file - Active scheme does not build this file"

This means the file isn't added to the Xcode project yet, so preview can't run.

## Quick Fix (2 minutes)

### Step 1: In Xcode, right-click on any onboarding file
Look for files like:
- EnhancedWelcomeView.swift
- AccountCreationView.swift  
- OnboardingFlowView.swift
- VoiceSelectionView.swift

These are likely grouped under "Models" or a similar folder in your project navigator.

### Step 2: Add the new file
1. Right-click on any of those onboarding files
2. Select "Add Files to 'StartSmart'..."
3. Navigate to: `StartSmart/Views/Onboarding/PremiumLandingPageV2.swift`
4. IMPORTANT: Check these boxes:
   - ✅ "Copy items if needed" (leave unchecked since file already exists)
   - ✅ "Add to targets: StartSmart" (VERY IMPORTANT!)
5. Click "Add"

### Step 3: Try preview again
Press `Cmd+Opt+P` - it should work now!

---

## Alternative: Add via Project Navigator

1. Find the folder containing onboarding files (look for files like "EnhancedWelcomeView.swift")
2. Right-click on that folder in project navigator
3. Select "Add Files to 'StartSmart'..."
4. Navigate to: `StartSmart/Views/Onboarding/PremiumLandingPageV2.swift`
5. Check "Add to targets: StartSmart"
6. Click "Add"
7. Press `Cmd+Opt+P`

---

## After Adding

The file should now:
- ✅ Appear in your project navigator
- ✅ Be part of the StartSmart target
- ✅ Allow preview (Cmd+Opt+P should work)
- ✅ Build successfully

---

## Still Having Issues?

If preview still doesn't work:
1. Clean build folder: `Cmd+Shift+K`
2. Build project: `Cmd+B`
3. Try preview again: `Cmd+Opt+P`

Let me know if you need more help!
