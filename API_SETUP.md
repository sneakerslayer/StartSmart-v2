# StartSmart API Setup Guide

This guide will help you configure the necessary API keys for the StartSmart app to function properly.

## Required API Keys

### 1. Grok4 API Key (AI Content Generation)

**What it's for:** Generating personalized motivational wake-up scripts

**How to get it:**
1. Visit [x.ai](https://x.ai) or the Grok API portal
2. Sign up for an account or log in
3. Navigate to API settings or developer console
4. Generate a new API key for Grok4

**Expected format:** String token (usually starts with `grok-` or similar)

### 2. ElevenLabs API Key (Text-to-Speech)

**What it's for:** Converting AI-generated text into high-quality speech audio

**How to get it:**
1. Visit [ElevenLabs.io](https://elevenlabs.io)
2. Create an account and verify your email
3. Go to your Profile → API Keys
4. Generate a new API key

**Expected format:** String token (usually alphanumeric)

**Free tier:** ElevenLabs offers a free tier with limited monthly characters

## Configuration Steps

### Option 1: Using Config.plist (Recommended for Development)

1. Copy the template file:
   ```bash
   cp StartSmart/Resources/Config-template.plist StartSmart/Resources/Config.plist
   ```

2. Edit `Config.plist` and replace the placeholder values:
   ```xml
   <key>GROK4_API_KEY</key>
   <string>your_actual_grok4_api_key_here</string>
   <key>ELEVENLABS_API_KEY</key>
   <string>your_actual_elevenlabs_api_key_here</string>
   ```

3. **Important:** Add `Config.plist` to `.gitignore` to keep your keys secure:
   ```bash
   echo "StartSmart/Resources/Config.plist" >> .gitignore
   ```

### Option 2: Using Environment Variables

Set environment variables in your development environment:

```bash
export GROK4_API_KEY="your_grok4_api_key"
export ELEVENLABS_API_KEY="your_elevenlabs_api_key"
```

### Option 3: Using Xcode Scheme Environment Variables

1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select "Run" from the left sidebar
3. Go to the "Arguments" tab
4. Add environment variables:
   - `GROK4_API_KEY` = your API key
   - `ELEVENLABS_API_KEY` = your API key

## Validation

The app will validate your configuration on startup. Check the console logs for any configuration issues:

```swift
let issues = ServiceConfiguration.validateConfiguration()
if !issues.isEmpty {
    print("Configuration issues: \(issues)")
}
```

## Security Best Practices

1. **Never commit API keys to version control**
2. **Use different keys for development and production**
3. **Rotate keys regularly**
4. **Monitor API usage to detect unusual activity**
5. **Consider using a backend service for production apps**

## Troubleshooting

### Common Issues

**"Grok4 API key is not configured"**
- Ensure your API key is properly set in Config.plist or environment variables
- Check that the key starts with the correct prefix

**"ElevenLabs API Error 401"**
- Verify your ElevenLabs API key is correct
- Check your ElevenLabs account has sufficient credits

**"Failed to decode response"**
- The API response format may have changed
- Check if you're using the correct API endpoints

### Debug Information

Use the built-in debug information to check your configuration:

```swift
let debugInfo = ServiceConfiguration.debugInfo()
print("Configuration status: \(debugInfo)")
```

## API Usage Limits

### Grok4
- Check current limits at x.ai documentation
- Implement rate limiting in production

### ElevenLabs
- Free tier: 10,000 characters/month
- Paid tiers: Various limits based on subscription
- Monitor usage in your ElevenLabs dashboard

## Production Considerations

For production deployment:

1. **Use a backend service** to proxy API calls and protect keys
2. **Implement proper error handling** for API failures
3. **Cache content** to reduce API calls
4. **Set up monitoring** for API usage and errors
5. **Consider fallback content** for offline scenarios

## Support

If you encounter issues:

1. Check the console logs for detailed error messages
2. Verify your API keys are correctly formatted
3. Test your API keys using the service providers' testing tools
4. Review the API documentation for any recent changes
