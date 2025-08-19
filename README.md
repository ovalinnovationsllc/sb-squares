# Super Bowl Squares 2026

A Flutter web application for managing Super Bowl squares games with Firebase backend.

## Features

- Admin dashboard for user management
- Four separate game boards (one per quarter)
- User authentication with email validation
- Responsive design for web deployment
- Comprehensive game instructions

## Setup Instructions

### 1. Firebase Configuration

**Important**: This project requires Firebase configuration that is not included in the repository for security reasons.

1. Copy the template file:
   ```bash
   cp lib/firebase_options.dart.template lib/firebase_options.dart
   ```

2. Replace the placeholder values in `lib/firebase_options.dart` with your actual Firebase project configuration:
   - Get your config from the Firebase Console → Project Settings → General → Your apps
   - Replace `YOUR_WEB_API_KEY_HERE`, `YOUR_PROJECT_ID_HERE`, etc. with actual values

3. Update Firestore security rules in Firebase Console:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       allow read, write: if true;
     }
   }
   ```

### 2. Running the Application

```bash
# Install dependencies
flutter pub get

# Run on web (localhost:8080)
flutter run -d web-server --web-port 8080
```

### 3. Admin Setup

The application uses email-based admin access. Update `lib/config/security_config.dart` to add admin email addresses.

## Project Structure

- `lib/models/` - Data models (UserModel)
- `lib/services/` - Firebase services (UserService) 
- `lib/pages/` - Application screens
- `lib/widgets/` - Reusable UI components
- `lib/config/` - Security and configuration files

## Development Notes

- Uses application-level security (no Firebase Auth)
- Firestore for user data storage
- Responsive design optimized for web
- Separate game boards for each quarter
