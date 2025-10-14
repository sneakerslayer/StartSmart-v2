# Firebase Demo User Setup for App Store Review

## Overview
Create a demo user directly in Firebase Console that Apple reviewers can use for testing, without needing to create a real Google account.

---

## ✅ Recommended Approach: Create User in Firebase Console

This is **much simpler** than creating a real Google account!

### Method 1: Email/Password Demo User (Easiest)

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com
   - Select your StartSmart project

2. **Navigate to Authentication:**
   - Click "Authentication" in left sidebar
   - Click "Users" tab at top

3. **Add User Manually:**
   - Click "Add user" button
   - **Email:** `demo@startsmart.app`
   - **Password:** `DemoStart2024!`
   - **User ID:** (auto-generated)
   - Click "Add user"

4. **The user is created!** ✅
   - No email verification needed
   - No real email account required
   - Ready to use immediately

---

### Method 2: Import Demo User via Firebase CLI (Advanced)

If you want more control:

```bash
# Install Firebase CLI if not already
npm install -g firebase-tools

# Login to Firebase
firebase login

# Create a JSON file: demo-user.json
{
  "users": [
    {
      "localId": "demo-user-001",
      "email": "demo@startsmart.app",
      "emailVerified": true,
      "passwordHash": "base64-encoded-hash",
      "salt": "base64-encoded-salt",
      "displayName": "StartSmart Demo",
      "photoUrl": "",
      "disabled": false,
      "metadata": {
        "createdAt": "1640000000000",
        "lastLoginAt": "1640000000000"
      }
    }
  ]
}

# Import the user
firebase auth:import demo-user.json --hash-algo=SCRYPT
```

---

## 🔧 Update Your App for Email/Password Demo Login

Since you currently only have Apple/Google sign-in, you need to add email/password authentication for the demo account.

### Option A: Add Email/Password Sign-In (Production-Ready)

Update `AccountCreationView.swift` to include email/password option:

```swift
// Add after Google Sign-In button

// Email/Password Sign-In (for demo/testing)
Button(action: {
    handleEmailPasswordSignIn()
}) {
    HStack {
        Image(systemName: "envelope.fill")
            .font(.title2)
        
        Text("Sign in with Email")
            .font(.system(size: 18, weight: .semibold))
    }
    .foregroundColor(.primary)
    .frame(height: 56)
    .frame(maxWidth: .infinity)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.systemGray4), lineWidth: 1.5)
    )
}
.disabled(isSigningIn)

// Add this function:
private func handleEmailPasswordSignIn() {
    // For review purposes, use demo credentials
    let email = "demo@startsmart.app"
    let password = "DemoStart2024!"
    
    isSigningIn = true
    
    Task {
        let success = await authService.signInWithEmail(email: email, password: password)
        
        await MainActor.run {
            isSigningIn = false
            
            if success {
                saveOnboardingData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            } else {
                onAuthError(authService.errorMessage ?? "Email sign in failed")
            }
        }
    }
}
```

### Option B: Hidden Demo Button (Review Only)

Add a **hidden** button that only Apple reviewers will know about:

```swift
// Add at the bottom of authentication section, in small text
Button(action: {
    handleDemoSignIn()
}) {
    Text("Demo Account (For App Review)")
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.4))
}
.padding(.top, 16)

private func handleDemoSignIn() {
    isSigningIn = true
    
    Task {
        // Sign in with pre-configured demo credentials
        let success = await authService.signInWithEmail(
            email: "demo@startsmart.app",
            password: "DemoStart2024!"
        )
        
        await MainActor.run {
            isSigningIn = false
            
            if success {
                saveOnboardingData()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete()
                }
            } else {
                onAuthError("Demo sign in failed")
            }
        }
    }
}
```

---

## 🔐 Configure Firebase Authentication

### Enable Email/Password Provider

1. **Firebase Console → Authentication → Sign-in method**
2. **Click "Email/Password"**
3. **Enable the toggle**
4. **Click "Save"**

That's it! Your Firebase project now supports email/password authentication.

---

## 🎯 Best Approach for App Store Review

### Recommendation: Use Email/Password with Hidden Demo Button

**Why this works best:**
- ✅ No need for real Google account
- ✅ No need for Apple to use their Apple ID
- ✅ You control the credentials
- ✅ Simple to set up in Firebase
- ✅ Easy to document in review notes

**Implementation:**
1. Enable Email/Password in Firebase
2. Create demo user: `demo@startsmart.app`
3. Add hidden demo button to `AccountCreationView`
4. Document in App Store review notes

---

## 📝 Updated Review Notes Template

Use this in App Store Connect:

```
DEMO ACCOUNT CREDENTIALS

PREFERRED METHOD (Email Sign-In):
Email: demo@startsmart.app
Password: DemoStart2024!

HOW TO SIGN IN:
1. Launch app and complete welcome screens
2. On account creation screen, scroll down
3. Tap "Demo Account (For App Review)" link at bottom
4. OR tap "Sign in with Email" button and use credentials above
5. Account is pre-configured with sample data

ALTERNATIVE METHODS:
- Sign in with Apple: Use your own Apple ID
- Sign in with Google: Create temporary Google account

PRE-CONFIGURED DEMO DATA:
✓ Onboarding completed
✓ 3 sample alarms created
✓ AI content generated and ready
✓ All features accessible

FEATURES TO TEST:
- Demo account login (preferred method)
- Create alarm with AI content generation
- Voice selection and preview
- Schedule alarm notification
- Dismiss alarm and hear AI script
- Analytics and streak tracking
- Subscription flow

TECHNICAL NOTES:
- Uses Firebase Authentication
- Email/password authentication enabled
- Demo user pre-configured in Firebase
- No verification required

PRIVACY:
- Voice processing is 100% on-device
- Privacy policy: https://startsmart.app/privacy
- No audio transmitted to servers
```

---

## 🛠️ Implementation Checklist

- [ ] **Firebase Console:**
  - [ ] Enable Email/Password authentication
  - [ ] Create demo user: `demo@startsmart.app`
  - [ ] Set password: `DemoStart2024!` (or your choice)
  - [ ] Verify user is active (not disabled)

- [ ] **Update AuthenticationService:**
  - [ ] Add `signInWithEmail(email:password:)` method
  - [ ] Test email/password authentication works

- [ ] **Update AccountCreationView:**
  - [ ] Add email/password sign-in button OR hidden demo button
  - [ ] Test demo sign-in flow
  - [ ] Verify it completes onboarding correctly

- [ ] **Pre-configure Demo Account:**
  - [ ] Sign in with demo account in simulator
  - [ ] Complete onboarding
  - [ ] Create 2-3 sample alarms
  - [ ] Generate AI content for at least one alarm
  - [ ] Test sign out and sign back in

- [ ] **Update Review Notes:**
  - [ ] Add demo credentials to App Store Connect
  - [ ] Include clear instructions for sign-in
  - [ ] Explain where to find demo button

---

## 💡 Bonus: Pre-Populate Demo User Data in Firestore

If you want the demo account to have data **without** manually creating it:

### Add Demo Data Script

```swift
// DemoDataSeeder.swift
import FirebaseFirestore
import FirebaseAuth

struct DemoDataSeeder {
    static func seedDemoAccount() async {
        guard let user = Auth.auth().currentUser,
              user.email == "demo@startsmart.app" else {
            return
        }
        
        let db = Firestore.firestore()
        let userId = user.uid
        
        // Create sample alarms
        let sampleAlarms = [
            [
                "id": UUID().uuidString,
                "time": Date().addingTimeInterval(3600).timeIntervalSince1970,
                "label": "Morning Workout",
                "isEnabled": true,
                "tone": "energetic",
                "useAIScript": true
            ],
            [
                "id": UUID().uuidString,
                "time": Date().addingTimeInterval(7200).timeIntervalSince1970,
                "label": "Daily Standup",
                "isEnabled": true,
                "tone": "professional",
                "useAIScript": true
            ]
        ]
        
        // Upload to Firestore
        for alarm in sampleAlarms {
            do {
                try await db.collection("users")
                    .document(userId)
                    .collection("alarms")
                    .addDocument(data: alarm)
            } catch {
                print("Error seeding demo data: \(error)")
            }
        }
        
        print("✅ Demo account seeded with sample data")
    }
}
```

Call this after demo user signs in:

```swift
if user.email == "demo@startsmart.app" {
    Task {
        await DemoDataSeeder.seedDemoAccount()
    }
}
```

---

## 🔒 Security Considerations

### Demo Account Security

1. **Weak password is OK:**
   - This is specifically for App Review
   - Not exposed to public
   - Only in App Store Connect review notes

2. **Firestore Security Rules:**
   - Ensure demo user can only access their own data
   - Standard user permissions apply

3. **Post-Review:**
   - Consider disabling demo account after approval
   - Or change password
   - Or leave it for future testing

---

## 📱 Testing the Demo Setup

### Complete Testing Flow

1. **Create Firebase demo user** ✅
2. **Enable email/password auth** ✅
3. **Add sign-in method to app** ✅
4. **Test on clean simulator:**
   ```
   - Reset simulator or use new device
   - Launch app
   - Complete onboarding
   - Sign in with demo credentials
   - Verify it works perfectly
   ```
5. **Pre-configure sample data** ✅
6. **Document in review notes** ✅

---

## 🎯 Quick Start: 5-Minute Setup

### Fastest Way to Get Demo Account Working

1. **Firebase Console** (2 minutes):
   - Go to Authentication → Users
   - Click "Add user"
   - Email: `demo@startsmart.app`
   - Password: `DemoStart2024!`
   - Click "Add user"

2. **Enable Email/Password** (1 minute):
   - Authentication → Sign-in method
   - Click "Email/Password"
   - Enable and save

3. **Update App** (2 minutes):
   - Add email/password sign-in button
   - Or add hidden demo button
   - Test in simulator

**Done!** You now have a working demo account.

---

## ❓ FAQ

**Q: Do I need to keep Google Sign-In?**
A: Yes, keep both Apple and Google. Email/password is just for demo/review.

**Q: Will reviewers see the demo button?**
A: Only if you document it in review notes. You can make it very subtle.

**Q: Can I use a different email?**
A: Yes! Use any email format: `appstore@startsmart.app`, `review@startsmart.app`, etc.

**Q: Do I need email verification?**
A: No! When you create the user in Firebase Console, they're automatically verified.

**Q: Should I add this to production?**
A: Email/password sign-in is fine for production. Many apps have it. Or remove after approval.

---

## ✅ Summary

**Best Approach:**
1. Create demo user in Firebase Console
2. Email: `demo@startsmart.app`
3. Password: Your choice (e.g., `DemoStart2024!`)
4. Add email/password sign-in to your app
5. Document in App Store review notes

**No need for:**
- ❌ Real Google account
- ❌ Fake Apple ID
- ❌ Complex setup

**Total time:** ~5-10 minutes ⚡

---

*This is the recommended approach for StartSmart demo account setup!*

