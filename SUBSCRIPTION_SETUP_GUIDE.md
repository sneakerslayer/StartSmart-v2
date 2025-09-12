# StartSmart Subscription Setup Guide

This guide covers the complete setup and configuration of the subscription system in StartSmart, including RevenueCat integration, App Store Connect configuration, and feature gating implementation.

## Table of Contents

1. [Overview](#overview)
2. [RevenueCat Setup](#revenuecat-setup)
3. [App Store Connect Configuration](#app-store-connect-configuration)
4. [Product Configuration](#product-configuration)
5. [Development Setup](#development-setup)
6. [Testing](#testing)
7. [Feature Gating](#feature-gating)
8. [Analytics](#analytics)
9. [Troubleshooting](#troubleshooting)

## Overview

StartSmart uses a freemium subscription model with the following tiers:

- **Free**: Up to 15 alarms per month, basic features
- **Pro Weekly**: $2.99/week, 3-day free trial
- **Pro Monthly**: $9.99/month, 7-day free trial (Popular)
- **Pro Annual**: $79.99/year, 7-day free trial, 33% discount

### Key Features by Tier

| Feature | Free | Pro |
|---------|------|-----|
| Monthly Alarm Limit | 15 | Unlimited |
| Voice Personalities | 1 (Energetic) | All 4 |
| Advanced Analytics | ❌ | ✅ |
| Social Sharing | ❌ | ✅ |
| Custom AI Content | ❌ | ✅ |
| Ad-Free Experience | ❌ | ✅ |

## RevenueCat Setup

### 1. Create RevenueCat Account

1. Sign up at [RevenueCat Dashboard](https://app.revenuecat.com)
2. Create a new project named "StartSmart"
3. Add your iOS app with bundle ID: `com.startsmart.app`

### 2. Configure Products

Create the following products in RevenueCat:

```
Product ID: startsmart_pro_weekly
Type: Auto-renewable subscription
Duration: 1 week
Trial: 3 days

Product ID: startsmart_pro_monthly  
Type: Auto-renewable subscription
Duration: 1 month
Trial: 7 days

Product ID: startsmart_pro_annual
Type: Auto-renewable subscription
Duration: 1 year
Trial: 7 days
```

### 3. Set Up Entitlements

Create an entitlement named `pro` that includes all three subscription products.

### 4. Get API Keys

1. Navigate to API Keys in RevenueCat Dashboard
2. Copy your **Public API Key** (starts with `appl_`)
3. Add to your `Config.plist`:

```xml
<key>REVENUECAT_API_KEY</key>
<string>appl_your_actual_api_key_here</string>
```

## App Store Connect Configuration

### 1. Create Subscription Group

1. In App Store Connect, go to your app
2. Navigate to Features → In-App Purchases
3. Create a new Subscription Group: "StartSmart Pro"

### 2. Create Subscription Products

Create three auto-renewable subscriptions:

#### Weekly Subscription
- **Product ID**: `startsmart_pro_weekly`
- **Reference Name**: StartSmart Pro Weekly
- **Duration**: 1 Week
- **Price**: $2.99 (Tier 3)
- **Free Trial**: 3 Days
- **Subscription Group**: StartSmart Pro

#### Monthly Subscription
- **Product ID**: `startsmart_pro_monthly`
- **Reference Name**: StartSmart Pro Monthly
- **Duration**: 1 Month
- **Price**: $9.99 (Tier 10)
- **Free Trial**: 7 Days
- **Subscription Group**: StartSmart Pro

#### Annual Subscription
- **Product ID**: `startsmart_pro_annual`
- **Reference Name**: StartSmart Pro Annual
- **Duration**: 1 Year
- **Price**: $79.99 (Tier 50)
- **Free Trial**: 7 Days
- **Subscription Group**: StartSmart Pro

### 3. Configure Subscription Details

For each subscription, add:

- **Display Name**: StartSmart Pro
- **Description**: "Unlock unlimited AI-powered alarms, all voice personalities, advanced analytics, and social sharing features."
- **Privacy Policy URL**: `https://startsmart.app/privacy`
- **Terms of Use URL**: `https://startsmart.app/terms`

### 4. Review Information

Add app review information including:
- Screenshots of paywall
- Test account credentials
- Review notes explaining subscription features

## Product Configuration

The subscription products are defined in `StartSmart/Models/Subscription.swift`:

```swift
static let weeklyProductId = "startsmart_pro_weekly"
static let monthlyProductId = "startsmart_pro_monthly"
static let annualProductId = "startsmart_pro_annual"
```

### Subscription Features

Features are defined in `SubscriptionFeature` struct:

```swift
static let unlimitedAlarms = SubscriptionFeature(...)
static let allVoices = SubscriptionFeature(...)
static let advancedAnalytics = SubscriptionFeature(...)
// ... etc
```

## Development Setup

### 1. Install Dependencies

The RevenueCat SDK is already included in `Package.swift`:

```swift
.package(url: "https://github.com/RevenueCat/purchases-ios", from: "4.31.0")
```

### 2. Configure API Keys

1. Copy `StartSmart/Resources/Config-template.plist` to `Config.plist`
2. Add your RevenueCat API key:

```xml
<key>REVENUECAT_API_KEY</key>
<string>appl_your_actual_api_key_here</string>
```

3. Add `Config.plist` to `.gitignore` to avoid committing API keys

### 3. Initialize Services

The subscription services are automatically initialized through dependency injection in `DependencyContainer.swift`:

```swift
let subscriptionService = SubscriptionService()
let subscriptionManager = SubscriptionManager(
    subscriptionService: subscriptionService,
    localStorage: localStorage
)
```

### 4. Configure RevenueCat

RevenueCat is automatically configured when the app launches. The configuration happens in `SubscriptionService.configureRevenueCat()`.

## Testing

### 1. Sandbox Testing

1. Create sandbox test accounts in App Store Connect
2. Sign out of App Store on device
3. Use sandbox account when testing purchases
4. Test all subscription flows:
   - Purchase
   - Free trial
   - Restore purchases
   - Cancellation
   - Renewal

### 2. Unit Tests

Run the subscription tests:

```bash
xcodebuild test -scheme StartSmart -destination 'platform=iOS Simulator,name=iPhone 15'
```

Key test files:
- `SubscriptionServiceTests.swift`
- `SubscriptionManagerTests.swift`

### 3. Integration Tests

Test the complete subscription flow:

1. **New User Flow**:
   - Open app → See free tier limitations
   - Try to create 16th alarm → Paywall appears
   - Purchase subscription → Unlimited access

2. **Existing User Flow**:
   - Open app with active subscription
   - Verify pro features are accessible
   - Test subscription expiration handling

### 4. Feature Gating Tests

Verify feature gating works correctly:

```swift
// Test unlimited alarms
let canCreate = subscriptionManager.canCreateAlarm()

// Test voice access
let canAccessVoices = subscriptionManager.canAccessFeature(.allVoices)

// Test analytics
let canAccessAnalytics = subscriptionManager.canAccessFeature(.advancedAnalytics)
```

## Feature Gating

### 1. Alarm Limits

Free users are limited to 15 alarms per month:

```swift
func canCreateAlarm() -> Bool {
    if currentSubscriptionStatus.isPremium {
        return true
    }
    
    guard let limit = currentSubscriptionStatus.monthlyAlarmLimit else {
        return true
    }
    
    return currentAlarmCount < limit
}
```

### 2. Voice Personalities

Only energetic voice is free, others require Pro:

```swift
// In VoiceSelectionGate
let isLocked = tone != .energetic && !subscriptionManager.canAccessFeature(.allVoices)
```

### 3. Advanced Features

Premium features are gated using `FeatureGateView`:

```swift
FeatureGateView(feature: .advancedAnalytics, source: "analytics") {
    AnalyticsDashboardView()
}
```

### 4. Social Sharing

Social sharing requires Pro subscription:

```swift
FeatureToggle(
    feature: .socialSharing,
    isEnabled: user.preferences.shareToSocialMediaEnabled,
    source: "settings"
) { enabled in
    // Update preference
}
```

## Analytics

### 1. Subscription Events

The system tracks key subscription events:

- `subscription_purchased`
- `subscription_cancelled`
- `paywall_presented`
- `feature_usage`

### 2. User Segmentation

Users are automatically segmented:

- `new_user`: Recent install, low usage
- `power_user`: High alarm usage, free tier
- `premium_user`: Active subscription
- `returning_user`: Older install, moderate usage

### 3. Paywall Optimization

Paywall configurations are optimized based on:

- Feature being accessed
- User segment
- Usage patterns
- A/B test variants

## Troubleshooting

### Common Issues

#### 1. RevenueCat Not Configured

**Error**: "RevenueCat API key is not configured"

**Solution**: 
- Verify `REVENUECAT_API_KEY` in `Config.plist`
- Ensure key starts with `appl_`
- Check key is not placeholder value

#### 2. Products Not Loading

**Error**: "No subscription options are currently available"

**Solutions**:
- Verify products exist in App Store Connect
- Check product IDs match exactly
- Ensure products are approved for sandbox testing
- Wait up to 24 hours for new products to propagate

#### 3. Purchases Not Working

**Error**: Purchase fails or hangs

**Solutions**:
- Use sandbox test account
- Sign out of App Store on device
- Verify network connection
- Check App Store Connect agreements are signed

#### 4. Feature Gating Not Working

**Issue**: Premium features accessible to free users

**Solutions**:
- Verify `SubscriptionManager` is properly injected
- Check subscription status updates
- Ensure feature checks use correct feature IDs
- Test with actual subscription state changes

### Debug Information

Use the debug info function to verify configuration:

```swift
let debugInfo = ServiceConfiguration.debugInfo()
print("Configuration: \(debugInfo)")
```

This shows:
- API key configuration status
- Feature flags
- Service settings

### Logging

Enable RevenueCat debug logging:

```swift
Purchases.logLevel = .debug
```

This provides detailed logs for:
- Purchase flows
- Receipt validation
- Subscription status changes
- API requests/responses

## Production Checklist

Before releasing:

- [ ] All subscription products created in App Store Connect
- [ ] Products approved and ready for sale
- [ ] RevenueCat properly configured with production API key
- [ ] Sandbox testing completed successfully
- [ ] Feature gating verified for all premium features
- [ ] Paywall UI/UX tested on multiple devices
- [ ] Privacy policy and terms of service updated
- [ ] App review information provided
- [ ] Analytics tracking implemented
- [ ] Error handling tested
- [ ] Restore purchases functionality working
- [ ] Subscription management links working

## Support

For additional help:

- [RevenueCat Documentation](https://docs.revenuecat.com)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [StartSmart Support](mailto:support@startsmart.app)

---

**Note**: This guide assumes you have proper Apple Developer Program membership and App Store Connect access. Some features may require additional setup or approval from Apple.
