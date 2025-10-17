# Apple & Google Sign-In Test Plan

## Overview
Verify that Apple and Google sign-in flows work correctly with the new guest mode feature.

## Build Status
✅ **Build Successful** - No compilation errors

---

## Test Scenarios

### Test 1: Guest Mode Flow (New Feature)
**Objective**: Verify guest mode doesn't break app functionality

**Steps**:
1. Launch app on iPhone simulator
2. Tap "Continue as Guest" button
3. Verify app transitions to MainAppView
4. Verify user can create alarms
5. Verify premium features show paywall

**Expected Result**: ✅ Guest user can access all free features

---

### Test 2: Apple Sign-In Flow (Existing Feature)
**Objective**: Verify Apple Sign-In still works after guest mode changes

**Prerequisites**:
- iOS Simulator or physical device
- Apple account for testing

**Steps**:
1. Launch app on device
2. Tap "Sign In with Apple" button (from onboarding or after dismissing guest mode)
3. Complete Apple Sign-In flow
4. Verify app transitions to MainAppView
5. Verify user profile is created in Firebase
6. Verify user can create alarms

**Expected Result**: ✅ Apple Sign-In completes successfully, user authenticated

**Code Path**:
```
OnboardingView.swift → handleAppleSignInResult()
  ↓
AuthenticationService.signInWithApple()
  ↓
FirebaseService.signInWithApple()
  ↓
Firestore: User profile created
  ↓
MainAppView: User authenticated
```

---

### Test 3: Google Sign-In Flow (Existing Feature)
**Objective**: Verify Google Sign-In still works after guest mode changes

**Prerequisites**:
- iOS Simulator or physical device
- Google account for testing
- GoogleService-Info.plist configured

**Steps**:
1. Launch app on device
2. Tap "Continue with Google" button
3. Complete Google Sign-In flow
4. Verify app transitions to MainAppView
5. Verify user profile is created in Firebase
6. Verify user can create alarms

**Expected Result**: ✅ Google Sign-In completes successfully, user authenticated

**Code Path**:
```
OnboardingView.swift → handleGoogleSignIn()
  ↓
AuthenticationService.signInWithGoogle()
  ↓
FirebaseService.signInWithGoogle()
  ↓
Firestore: User profile created
  ↓
MainAppView: User authenticated
```

---

### Test 4: State Transitions
**Objective**: Verify authentication state transitions work correctly

**Steps**:
1. Check `AuthenticationService.authenticationState` transitions:
   - `.signedOut` (initial state)
   - `.signingIn` (during sign-in)
   - `.signedIn` (after successful sign-in)
   - `.error` (if sign-in fails)

**Expected Result**: ✅ All state transitions occur correctly

---

### Test 5: Guest Mode to Sign-In Transition
**Objective**: Verify user can sign in after starting as guest

**Steps**:
1. Launch app, tap "Continue as Guest"
2. User accesses app as guest
3. User navigates to settings or tries premium feature
4. User taps "Sign In" (if available)
5. Complete sign-in flow
6. Verify guest data is preserved or migrated appropriately

**Expected Result**: ✅ User can transition from guest to authenticated

---

### Test 6: Authentication Error Handling
**Objective**: Verify app handles auth errors gracefully

**Steps**:
1. Test with invalid credentials
2. Test with network interruption (airplane mode)
3. Test cancel during sign-in
4. Verify error is displayed to user
5. Verify user can retry

**Expected Result**: ✅ Errors handled gracefully with user-friendly messages

---

## Code Changes Impact Analysis

### Files Modified
1. **AuthenticationService.swift**
   - Added: `isGuestMode` property (line 43)
   - Added: `enableGuestMode()` method (lines 240-268)
   - Added: `exitGuestMode()` method (lines 271-273)
   - Status: ✅ Isolated changes, doesn't affect sign-in methods

2. **OnboardingView.swift**
   - Added: "Continue as Guest" button (lines 149-172)
   - Added: `handleGuestMode()` method (lines 277-280)
   - Modified: Sign-in button handlers remain unchanged
   - Status: ✅ New button doesn't interfere with existing sign-in

3. **EnhancedWelcomeView.swift**
   - Modified: Terms/Privacy buttons to Links (functional)
   - Status: ✅ UI only, doesn't affect authentication

4. **SettingsView.swift**
   - Modified: Added Legal links
   - Status: ✅ UI only, doesn't affect authentication

### Impact on Sign-In Flow
- ✅ `signInWithApple()` method unchanged (lines 108-141)
- ✅ `signInWithGoogle()` method unchanged (lines 163-198)
- ✅ `updateAuthenticationState()` unchanged
- ✅ Firebase integration unchanged
- ✅ User profile creation unchanged

**Conclusion**: Sign-in logic is completely isolated from guest mode implementation

---

## Testing Checklist

### Pre-Test
- [ ] Project builds successfully
- [ ] No compilation errors
- [ ] Dependencies installed
- [ ] Firebase configured
- [ ] Google Sign-In configured

### Guest Mode Tests
- [ ] Guest button appears on onboarding
- [ ] Guest mode completes onboarding
- [ ] Guest user can access main app
- [ ] Guest user can create alarms
- [ ] Guest user sees paywall for premium

### Apple Sign-In Tests
- [ ] Apple Sign-In button appears
- [ ] Sign-In dialog shows
- [ ] User can authenticate
- [ ] Firestore user created
- [ ] MainAppView shows authenticated user
- [ ] User can create alarms

### Google Sign-In Tests
- [ ] Google Sign-In button appears
- [ ] Sign-In dialog shows
- [ ] User can authenticate
- [ ] Firestore user created
- [ ] MainAppView shows authenticated user
- [ ] User can create alarms

### Legal Links Tests
- [ ] Privacy Policy link works
- [ ] Terms of Service link works
- [ ] Links open in Safari
- [ ] Links accessible from onboarding
- [ ] Links accessible from settings

### Error Handling Tests
- [ ] Apple Sign-In cancellation handled
- [ ] Google Sign-In cancellation handled
- [ ] Network errors handled
- [ ] Error messages display
- [ ] User can retry

---

## Quick Test Commands

### Build for Simulator
```bash
cd /Users/robertkovac/StartSmart-v2
xcodebuild -scheme StartSmart -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build
```

### Run on Simulator
```bash
# After building, launch simulator and install app
# Or use Xcode's Run button (Cmd+R)
```

---

## Known Issues / Considerations

1. **Simulator Limitations**:
   - Apple Sign-In may not work fully on simulator (requires physical device for testing)
   - Google Sign-In might require special configuration

2. **Firebase Configuration**:
   - Ensure GoogleService-Info.plist is present
   - Verify Firebase project settings

3. **Guest Mode State**:
   - Guest mode sets onboarding as complete
   - User would need to reset app data to become guest again after signing in

---

## Test Results Template

```
Test Scenario: [Scenario Name]
Device: [iPhone X, Simulator, etc.]
iOS Version: 26.0+
Result: [PASS / FAIL / PARTIAL]
Notes: [Any issues found]
```

---

## Sign-In Method Reference

### Apple Sign-In Flow
```swift
// User taps "Sign In with Apple"
OnboardingView.handleAppleSignInResult()
  → AuthenticationService.signInWithApple()
    → ASAuthorizationAppleIDProvider.requestAppleAuthorization()
      → FirebaseService.signInWithApple(idToken, nonce)
        → Firebase Auth
        → Firestore: Create/Load user profile
          → AuthenticationService.updateAuthenticationState()
            → AuthenticationView shows MainAppView
```

### Google Sign-In Flow
```swift
// User taps "Continue with Google"
OnboardingView.handleGoogleSignIn()
  → AuthenticationService.signInWithGoogle()
    → GIDSignIn.sharedInstance.signIn()
      → FirebaseService.signInWithGoogle(idToken, accessToken)
        → Firebase Auth
        → Firestore: Create/Load user profile
          → AuthenticationService.updateAuthenticationState()
            → AuthenticationView shows MainAppView
```

---

## Expected Behavior After Tests

### Sign-In Success
- User authenticated in Firebase
- User profile created/loaded in Firestore
- `isAuthenticated = true`
- `authenticationState = .signedIn`
- `currentUser` populated with user data
- MainAppView displays with user's data

### Guest Mode Success
- `isGuestMode = true`
- `isAuthenticated = false`
- Onboarding marked as complete
- User can create alarms locally
- Premium features show paywall

---

**Last Updated**: October 17, 2025
**Build Status**: ✅ SUCCESS
**Ready for Testing**: YES
