# Firebase Setup Instructions

## 🔥 Firebase Configuration for StartSmart

### Prerequisites
- Google account (to access Firebase Console)
- Xcode project with bundle ID: `com.startsmart.mobile`

### Step 1: Create Firebase Project

1. **Go to Firebase Console:** https://console.firebase.google.com/
2. **Sign in** with your Google account
3. **Create a project:**
   - Project name: `StartSmart` (or `StartSmart-Mobile` if taken)
   - Enable Google Analytics: ✅ **Yes** (recommended)
   - Analytics account: Create new or use existing

### Step 2: Add iOS App

1. **In Firebase project, click "Add app" → iOS**
2. **iOS bundle ID:** `com.startsmart.mobile` ⚠️ **MUST MATCH EXACTLY**
3. **App nickname:** `StartSmart iOS`
4. **App Store ID:** Leave blank for now
5. **Click "Register app"**

### Step 3: Download Configuration

1. **Download GoogleService-Info.plist** when prompted
2. **CRITICAL:** Place this file at:
   ```
   /Users/robertkovac/StartSmart-v2/StartSmart/Resources/GoogleService-Info.plist
   ```

### Step 4: Enable Firebase Services

#### Authentication
1. Go to **Authentication** → **Get started**
2. Go to **Sign-in method** tab
3. **Enable Google:**
   - Click "Google" → Toggle **Enable** → Save
4. **Enable Apple:**
   - Click "Apple" → Toggle **Enable** → Save

#### Firestore Database
1. Go to **Firestore Database** → **Create database**
2. **Security rules:** Start in **test mode** (we'll secure later)
3. **Location:** Choose `us-central1` (or closest to your users)

#### Storage
1. Go to **Storage** → **Get started**
2. **Security rules:** Start in **test mode**
3. **Location:** Use same as Firestore

### Step 5: Verify Configuration

After placing `GoogleService-Info.plist` in the Resources folder, the app should:

1. ✅ Compile without Firebase errors
2. ✅ Show Firebase services as available
3. ✅ Pass all configuration tests

### Testing Your Setup

Run the Firebase configuration tests:
```bash
# From Xcode, run tests for:
FirebaseConfigurationTests
```

These tests will verify:
- ✅ GoogleService-Info.plist exists and is valid
- ✅ Bundle ID matches (`com.startsmart.mobile`)
- ✅ Firebase services (Auth, Firestore, Storage) are available
- ✅ Dependency injection is working

### Troubleshooting

**Common Issues:**

1. **"GoogleService-Info.plist not found"**
   - Ensure file is in `StartSmart/Resources/` folder
   - Check filename is exactly `GoogleService-Info.plist`

2. **Bundle ID mismatch**
   - Firebase bundle ID must be `com.startsmart.mobile`
   - Check Xcode project settings match

3. **Services not available**
   - Restart Xcode after adding plist file
   - Clean build folder (Cmd+Shift+K)

### What's Ready After Setup

Once Firebase is configured, the following will be functional:

✅ **FirebaseService** - Backend integration
✅ **AuthenticationService** - Apple & Google Sign In
✅ **User Profile Management** - Firestore storage
✅ **Alarm Synchronization** - Cross-device sync
✅ **Audio Content Storage** - Cloud storage for TTS files

### Next Steps

After Firebase setup is complete, we'll proceed with:
- **Task 2.2:** Authentication UI Development
- **Task 2.3:** Authentication Integration Testing
- **Task 2.4:** Complete Authentication Flow

Let me know when you've completed the Firebase setup!
