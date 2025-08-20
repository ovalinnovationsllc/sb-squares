# Firebase Configuration Setup

## Important Security Note
Firebase configuration files (`google-services.json` and `GoogleService-Info.plist`) are excluded from version control for security reasons. While Firebase API keys are designed to be public and are protected by Firebase Security Rules, it's best practice to keep them out of public repositories.

## Setup Instructions

### For New Developers

1. **Obtain Firebase Configuration Files**
   - Contact the project administrator to get the actual Firebase configuration files
   - Or create your own Firebase project for development

2. **Android Setup**
   - Copy `android/app/google-services.json.example` to `android/app/google-services.json`
   - Replace placeholder values with actual Firebase configuration

3. **iOS Setup**
   - Copy `ios/Runner/GoogleService-Info.plist.example` to `ios/Runner/GoogleService-Info.plist`
   - Replace placeholder values with actual Firebase configuration

4. **Web/Dart Setup**
   - The `lib/firebase_options.dart` file is auto-generated
   - Run `flutterfire configure` after setting up Firebase project

### Creating Your Own Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project or select existing one
3. Add Android app with package name: `com.llc.sb_squares`
4. Add iOS app with bundle ID: `com.llc.sbSquares`
5. Download configuration files and place them in appropriate locations
6. Enable Authentication and Firestore in Firebase Console

### Security Rules
Ensure proper Firebase Security Rules are configured in Firebase Console:
- Firestore Database rules
- Authentication settings
- API key restrictions (recommended for production)

## Production Deployment

For production deployments:
1. Use environment-specific Firebase projects
2. Restrict API keys in Google Cloud Console
3. Configure proper domain restrictions for web
4. Set up proper Firebase Security Rules

## Troubleshooting

If you encounter issues:
1. Ensure configuration files are in correct locations
2. Verify package name/bundle ID matches Firebase configuration
3. Check that required Firebase services are enabled
4. Verify Firebase Security Rules allow your operations