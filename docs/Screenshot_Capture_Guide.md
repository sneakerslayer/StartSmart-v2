# StartSmart Screenshot Capture Guide

## Setup Complete ✅
- **Simulator**: iPhone 16 Pro Max (6.7" display) - Booted and ready
- **App**: StartSmart running in simulator
- **Screenshot 1**: Already captured at `/Users/robertkovac/Downloads/screenshot_1_hero.png`

## Manual Screenshot Capture Instructions

### How to Capture Screenshots
Since the simulator is already running, you have two options:

**Option 1: Use Simulator Menu**
1. Click on the Simulator window to bring it to front
2. Go to: `File → New Screenshot` (or press `⌘S`)
3. Screenshot saves to Desktop by default

**Option 2: Use Terminal Command** (I'll run these for you)
- I can capture screenshots using the command line tool

### Screenshots to Capture (6 Total)

#### ✅ Screenshot 1: Hero/Welcome Screen - CAPTURED
- **File**: `screenshot_1_hero.png`
- **Location**: `/Users/robertkovac/Downloads/screenshot_1_hero.png`
- **Status**: ✅ Complete
- **Current screen showing**: Welcome/onboarding with "Design My Wake-Up" button

---

#### 📸 Screenshot 2: Alarm Creation Form (Intent + Tone)
- **Navigation**: Tap "Design My Wake-Up" button OR "Already have an account? Sign In" → then create new alarm
- **Expected Screen**: AlarmFormView showing:
  - Time picker
  - "What's your intention?" input field
  - Tone/personality selection (Gentle, Energetic, Tough Love, Storyteller)
- **What to capture**: Full screen with form filled out (example: "I want to exercise today")

---

#### 📸 Screenshot 3: Voice Selection
- **Navigation**: From alarm form, proceed to voice selection
- **Expected Screen**: VoiceSelectionView showing:
  - 4 voice personality cards (Gentle, Energetic, Tough Love, Storyteller)
  - Each with play button and description
  - One selected/highlighted
- **What to capture**: Full screen with one voice selected

---

#### 📸 Screenshot 4: Full-Screen Alarm (Active Alarm)
- **Navigation**: 
  - Option A: Create an alarm and wait for it to trigger
  - Option B: From home screen, tap an existing alarm that has "AI-Generated Content Ready"
  - Option C: Use the debug/test alarm feature if available
- **Expected Screen**: AlarmDismissalView showing:
  - Large time display (e.g., "6:30 AM")
  - Waveform visualization
  - "Playing your AI script..." message
  - Stop and Dismiss buttons
  - Full gradient background
- **What to capture**: Full screen while alarm is active/playing

---

#### 📸 Screenshot 5: Streaks & Analytics (Home Screen)
- **Navigation**: 
  - Complete onboarding to reach main app
  - Tap "Home" in bottom navigation (if not already there)
- **Expected Screen**: Home/Dashboard showing:
  - "Good Morning!" greeting
  - Current streak counter (e.g., "7 days") with fire emoji
  - Week view with day indicators
  - Next alarm card
  - Recent activity section
  - Bottom navigation bar
- **What to capture**: Full home screen with streak and analytics visible

---

#### 📸 Screenshot 6: Paywall/Subscription Screen
- **Navigation**: 
  - From home screen, try to create 4th alarm (triggers paywall on free plan)
  - OR tap on premium feature
  - OR look for "Upgrade" or "Pro" option in settings/menu
- **Expected Screen**: PaywallView showing:
  - Subscription tiers (Weekly, Monthly, Annual)
  - Feature list with checkmarks
  - Pricing information
  - "Start Free Trial" button
  - "Best Value" or "Most Popular" badges
- **What to capture**: Full paywall screen with all tiers visible

---

## Current Status

**Your simulator is ready!** The iPhone 16 Pro Max is running with StartSmart loaded.

### Next Steps:

1. **Bring simulator to front** - Click on the Simulator window
2. **Navigate through the app** following the sequence above
3. **For each screen, tell me when you're ready** and I'll capture the screenshot using the command line

OR

4. **Manually capture** using `⌘S` in Simulator and tell me the filenames so I can organize them

---

## Screenshot Organization

Once captured, I'll:
1. Move all screenshots to `/Users/robertkovac/StartSmart-v2/app_store_screenshots/`
2. Rename them properly:
   - `01_hero_welcome.png`
   - `02_alarm_form_intent_tone.png`
   - `03_voice_selection.png`
   - `04_alarm_active_fullscreen.png`
   - `05_home_streaks_analytics.png`
   - `06_paywall_subscription.png`
3. Verify dimensions (should be 1290 x 2796 pixels for 6.7" iPhone)
4. Create text overlay versions following the Screenshot Storyboard

---

## Tips for Best Screenshots

1. **Use realistic data**: Fill forms with real-looking content
2. **Show active states**: Buttons highlighted, content loaded
3. **Set nice time**: Maybe change simulator time to something like 6:30 AM for alarm
4. **Good streaks**: If possible, show 7-day streak with progress
5. **Clean UI**: Make sure no error states or loading spinners unless intentional

Let me know when you're ready to capture each screenshot!

