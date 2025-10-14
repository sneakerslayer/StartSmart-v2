# StartSmart Demo Account Setup for App Review

## Overview
Apple requires a demo account for testing apps with authentication. This guide explains how to set up and provide demo credentials for App Store review.

---

## ⚠️ Important: Apple Sign In Cannot Use Demo Account

**Apple's Requirements:**
- You **cannot** create a fake Apple ID for reviewers
- Apple reviewers will use their own Apple ID to test "Sign in with Apple"
- This is standard practice and Apple expects it

**Solution:**
- Configure your app to handle new Apple Sign In users seamlessly
- Ensure first-time users get full access (no special setup required)
- Reviewers will sign in with their real Apple ID during review

---

## ✅ Recommended Approach: Google Sign-In Demo Account

Since Apple reviewers can't use a demo Apple ID, provide a **Google account** for testing:

### Create Demo Google Account

1. **Go to:** https://accounts.google.com/signup
2. **Create account with these details:**
   - **Email:** `startsmart.demo@gmail.com` (or similar)
   - **Password:** `[Create strong password]`
   - **Name:** StartSmart Demo
   - **Birthday:** Jan 1, 1990 (make them 18+)

3. **Verify the account:**
   - Complete phone verification
   - Accept terms
   - Skip all optional steps

4. **Pre-configure in your app:**
   - Sign in once with this account
   - Complete full onboarding flow
   - Set up sample alarms
   - Generate sample AI content

---

## 📝 Review Notes Template

Add this to your **App Review Information** in App Store Connect:

```
DEMO ACCOUNT CREDENTIALS

Email: startsmart.demo@gmail.com
Password: [Your password here]

SIGN-IN METHOD: Google Sign-In (Continue with Google button)

TESTING INSTRUCTIONS:
1. Launch app and complete welcome screens
2. On account creation screen, tap "Continue with Google"
3. Use the demo credentials above
4. The account is pre-configured with:
   - Sample alarms
   - Completed onboarding preferences
   - AI content generation ready
   - All features unlocked for testing

APPLE SIGN IN:
Apple reviewers can also test with their own Apple ID.
The app will work seamlessly with any Apple ID - no special configuration needed.

SUBSCRIPTION TESTING:
- App uses RevenueCat + StoreKit 2
- Sandbox environment configured
- Test subscription purchases are enabled
- No real payment will be charged

FEATURES TO TEST:
1. Google authentication (use demo account above)
2. Create alarm with AI content generation
3. Voice selection and preview
4. Schedule alarm and receive notification
5. Dismiss alarm and hear AI script
6. View analytics and streak tracking
7. Subscription flow (optional)

KNOWN LIMITATIONS:
- Audio generation requires API keys (configured)
- Notifications best tested on physical device
- Some features require internet connection

PRIVACY:
- Voice processing is 100% on-device
- Uses Apple Speech Recognition framework
- No audio is recorded or transmitted
- Privacy policy: https://startsmart.app/privacy

SUPPORT CONTACT:
Email: support@startsmart.app
Response time: 24 hours
```

---

## 🔧 Pre-Configure Demo Account

Before submitting, sign in with the demo account and:

### 1. Complete Onboarding
- ✅ Select motivation (e.g., "Fitness")
- ✅ Set tone preference (e.g., 70% - Energetic)
- ✅ Choose voice (e.g., "Alex - Energetic Coach")
- ✅ Grant notification permissions (if possible in simulator)

### 2. Create Sample Alarms
Create 2-3 sample alarms:

**Alarm 1: "Morning Workout"**
- Time: 7:00 AM
- Intent: "Hit the gym and crush leg day"
- Voice: Alex - Energetic Coach
- Status: Enabled

**Alarm 2: "Daily Standup"**
- Time: 9:30 AM
- Intent: "Be prepared for team standup meeting"
- Voice: Sarah - Calm Professional
- Status: Enabled

**Alarm 3: "Evening Review"**
- Time: 6:00 PM
- Intent: "Review today's accomplishments"
- Voice: Marcus - Motivational Speaker
- Status: Disabled (to show UI for both states)

### 3. Generate AI Content
- Trigger AI content generation for at least one alarm
- Ensure text-to-speech has generated audio
- Verify audio plays correctly

### 4. Document Current State
Take screenshots of:
- Alarm list view
- Sample alarm details
- Analytics/insights (if any data)
- Settings screen

---

## 🎭 Alternative: Bypass Authentication for Review (NOT RECOMMENDED)

**⚠️ Warning:** This is generally discouraged, but some apps provide a "Reviewer Account" that bypasses auth.

**If you must do this:**

```swift
// Add to AccountCreationView.swift - ONLY for review, remove after approval

#if DEBUG || REVIEWER_BUILD
Button(action: {
    // Create mock reviewer account
    createReviewerAccount()
}) {
    Text("Apple Reviewer Login")
        .font(.caption)
        .foregroundColor(.white.opacity(0.5))
}
.padding(.top, 20)
#endif
```

**Better approach:** Don't do this. Use the Google demo account method above.

---

## 📱 Test Demo Account Before Submission

### Verification Checklist

On a **clean simulator** (or reset device):

1. **Launch app**
   - ✅ Onboarding screens appear
   - ✅ No crashes or freezes

2. **Sign in with demo account**
   - ✅ Tap "Continue with Google"
   - ✅ Enter demo credentials
   - ✅ Successfully signs in
   - ✅ Preferences load correctly

3. **Test core features**
   - ✅ View existing alarms
   - ✅ Create new alarm
   - ✅ Generate AI content
   - ✅ Schedule alarm
   - ✅ Test notification (if possible)

4. **Test edge cases**
   - ✅ Sign out and sign back in
   - ✅ Force quit and relaunch
   - ✅ Airplane mode (offline features)

---

## 🔐 Security Best Practices

### Demo Account Security

1. **Use a dedicated email:**
   - Don't use your personal Gmail
   - Create `startsmart.demo@gmail.com` or similar
   - Only use it for demo purposes

2. **Strong but shareable password:**
   - Use a password manager to generate
   - Format: `DemoStart2024!SmartTest`
   - Include in App Review notes only (not public)

3. **Limit access:**
   - This account should have no personal data
   - No real payment methods attached
   - No sensitive information stored

4. **Monitor usage:**
   - Check login history after review
   - Change password after approval
   - Disable account if not needed

---

## 📋 App Store Connect Configuration

### Where to Add Demo Credentials

1. **Go to:** App Store Connect → Your App → App Review Information
2. **Find:** "Sign-in required" section
3. **Add:**
   ```
   Username: startsmart.demo@gmail.com
   Password: [Your password]
   
   Sign-in method: Google (Continue with Google button)
   ```

4. **Add Notes (optional but recommended):**
   - Use the Review Notes Template above
   - Explain how to use the demo account
   - List features that should be tested
   - Note any limitations or special instructions

---

## 🎯 What Apple Reviews Will Test

Based on typical App Store reviews, expect them to:

### Basic Functionality
- ✅ Launch app and complete onboarding
- ✅ Sign in successfully
- ✅ Navigate main features
- ✅ Create/edit/delete content (alarms)
- ✅ Test notifications
- ✅ Sign out

### Privacy & Permissions
- ✅ Review permission requests
- ✅ Check privacy policy link works
- ✅ Verify data handling matches declarations
- ✅ Test "Sign in with Apple" (with their own ID)

### Subscriptions (if applicable)
- ✅ View subscription options
- ✅ Initiate purchase flow (won't complete)
- ✅ Check restore purchases
- ✅ Verify terms are clear

### Edge Cases
- ✅ Force quit and relaunch
- ✅ Background/foreground
- ✅ Network connectivity issues
- ✅ Invalid inputs

---

## 🚨 Common Review Rejection Reasons Related to Demo Accounts

### Avoid These Issues

1. **"Demo account doesn't work"**
   - ❌ Password expired
   - ❌ Account locked
   - ❌ Two-factor authentication enabled
   - ✅ **Solution:** Test demo account right before submission

2. **"Can't test core features"**
   - ❌ Demo account has no data
   - ❌ Features require payment
   - ❌ Content generation fails
   - ✅ **Solution:** Pre-configure demo account with sample data

3. **"Sign in process is confusing"**
   - ❌ No clear instructions
   - ❌ Multiple auth methods, unclear which to use
   - ❌ Error messages not helpful
   - ✅ **Solution:** Add clear instructions in review notes

---

## 📞 Support During Review

Apple may contact you during review if:
- Demo account issues arise
- Features don't work as expected
- Privacy questions come up

**Be prepared to respond within 24 hours:**
- Monitor email: [your email]
- Keep demo account accessible
- Have backup credentials ready

---

## ✅ Final Checklist

Before submitting:

- [ ] Google demo account created and verified
- [ ] Demo account has completed onboarding
- [ ] 2-3 sample alarms created with AI content
- [ ] Demo account tested on clean simulator
- [ ] Credentials added to App Store Connect
- [ ] Review notes include testing instructions
- [ ] Privacy policy URL is accessible
- [ ] All features work with demo account
- [ ] No two-factor authentication on demo account
- [ ] Password is strong but memorable
- [ ] Support email is monitored

---

## 📝 Quick Setup Script

```bash
# Demo Account Quick Setup
# Run these steps manually to prepare demo account

1. Create Google account: startsmart.demo@gmail.com
2. Launch simulator: xcrun simctl list | grep "iPhone"
3. Build and run: Cmd + R in Xcode
4. Complete onboarding with demo preferences
5. Create 3 sample alarms
6. Test sign out and sign back in
7. Take screenshots for documentation
8. Note credentials in secure location
9. Add to App Store Connect review info
```

---

## 🎉 Demo Account Template

Copy this and fill in your details:

```
═══════════════════════════════════════
STARTSMART DEMO ACCOUNT
═══════════════════════════════════════

EMAIL: startsmart.demo@gmail.com
PASSWORD: [Your secure password]
AUTH METHOD: Google Sign-In

PRE-CONFIGURED DATA:
✓ Onboarding completed
✓ 3 sample alarms created
✓ AI content generated
✓ Notifications enabled
✓ Premium features accessible

TESTING NOTES:
- Use "Continue with Google" button
- Enter credentials above
- All features ready to test
- No setup required

APPLE REVIEWER ALTERNATIVE:
- Can use own Apple ID
- Will work seamlessly
- No demo Apple ID needed

SUPPORT:
support@startsmart.app
═══════════════════════════════════════
```

---

**Save this document and follow the steps before App Store submission!**

*Last Updated: [DATE]*
*Keep credentials secure and only share via App Store Connect*

