# Checking Firebase Config Collection

## The config collection should now be created automatically

When the app starts, it automatically creates the config collection with default values:
- **Home Team**: AFC
- **Away Team**: NFC

## How to Verify in Firebase Console

1. Go to your Firebase Console: https://console.firebase.google.com
2. Select your project
3. Navigate to **Firestore Database**
4. Look for the **config** collection
5. You should see a document with:
   ```
   awayTeamName: "NFC"
   homeTeamName: "AFC"
   isActive: true
   updatedAt: [timestamp]
   updatedBy: "System"
   ```

## If the Collection Doesn't Exist

The app will create it automatically on startup. The initialization code in `main.dart` runs:
```dart
// Initialize game configuration if it doesn't exist
final configService = GameConfigService();
await configService.createDefaultConfig();
```

## Testing the Configuration

1. **View Current Teams**: 
   - Open the game board at http://localhost:8082
   - You should see "AFC" and "NFC" as the team names

2. **Change Team Names**:
   - Login as an admin
   - Go to Admin Dashboard
   - Find the "Team Names" section
   - Click "Edit Teams"
   - Enter new names (e.g., "CHIEFS" and "EAGLES")
   - Click Save

3. **Real-time Updates**:
   - Open the game in another browser
   - When admin changes team names, they update instantly for all users

## Manual Creation (if needed)

If for some reason the automatic creation doesn't work, you can manually create the collection in Firebase Console:

1. Go to Firestore Database
2. Click "Start collection"
3. Collection ID: `config`
4. Add a document with these fields:
   - `awayTeamName` (string): "NFC"
   - `homeTeamName` (string): "AFC"
   - `isActive` (boolean): true
   - `updatedAt` (timestamp): Current time
   - `updatedBy` (string): "Manual Setup"

## Troubleshooting

If you don't see the config collection:
1. Check the browser console for any errors (F12 → Console tab)
2. Restart the app with hot restart (press R in terminal)
3. Check Firebase rules allow read/write to config collection
4. Verify your Firebase project is properly connected