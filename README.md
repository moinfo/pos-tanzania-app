# POS Tanzania Mobile App

Flutter mobile application for Point of Sales Tanzania system with Z Reports and Cash Submission features.

## Features

- **Authentication**: JWT-based login with secure token storage
- **Z Reports**: View, create, and submit Z Reports with file attachments
- **Cash Submissions**: Submit cash with supervisor approval workflow
- **Offline Support**: Secure storage for authentication tokens
- **Tanzania-Specific**: TRA compliance features (Z Reports, EFD)

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- Running API backend (see ../API_DOCUMENTATION.md)

## Installation

### 1. Install Flutter

Follow official Flutter installation guide: https://docs.flutter.dev/get-started/install

### 2. Install Dependencies

```bash
cd pos_tanzania_mobile
flutter pub get
```

### 3. Configure API Base URL

Edit `lib/services/api_service.dart` and update the base URL:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:8888/PointOfSalesTanzania/public/api';
```

**For Android Emulator:**
```dart
static const String baseUrl = 'http://10.0.2.2:8888/PointOfSalesTanzania/public/api';
```

**For iOS Simulator:**
```dart
static const String baseUrl = 'http://localhost:8888/PointOfSalesTanzania/public/api';
```

**For Physical Device:**
```dart
static const String baseUrl = 'http://YOUR_LOCAL_IP:8888/PointOfSalesTanzania/public/api';
```

## Running the App

### Android

```bash
flutter run
```

### iOS

```bash
flutter run
```

### Web (for testing)

```bash
flutter run -d chrome
```

## Project Structure

```
lib/
├── main.dart                   # App entry point
├── models/                     # Data models
│   ├── api_response.dart
│   ├── user.dart
│   ├── z_report.dart
│   ├── cash_submission.dart
│   └── supervisor.dart
├── providers/                  # State management
│   └── auth_provider.dart
├── screens/                    # UI screens
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── z_reports_screen.dart
│   └── cash_submit_screen.dart
├── services/                   # API services
│   └── api_service.dart
├── utils/                      # Utilities
│   ├── constants.dart
│   └── formatters.dart
└── widgets/                    # Reusable widgets
```

## Default Login Credentials

```
Username: admin
Password: kibahatz
```

## API Endpoints Used

### Authentication
- `POST /api/auth/login` - User login
- `POST /api/auth/verify` - Verify token
- `POST /api/auth/refresh` - Refresh token
- `POST /api/auth/logout` - Logout

### Z Reports
- `GET /api/zreports` - List all Z reports
- `GET /api/zreports/{id}` - Get single Z report
- `POST /api/zreports/create` - Create Z report with file
- `DELETE /api/zreports/delete/{id}` - Delete Z report

### Cash Submissions
- `GET /api/cashsubmit` - List all cash submissions
- `GET /api/cashsubmit/{id}` - Get single submission
- `POST /api/cashsubmit/create` - Create cash submission
- `GET /api/cashsubmit/supervisors` - Get supervisors list

## Building for Production

### Android APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Google Play)

```bash
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

## Troubleshooting

### API Connection Issues

1. **Check API Base URL**: Ensure it matches your server configuration
2. **Network Permissions**: Android requires network permissions in `AndroidManifest.xml`
3. **CORS**: Ensure API allows your app's origin
4. **Firewall**: Check if firewall is blocking connections

### File Upload Issues

1. **Permissions**: Ensure app has storage permissions
2. **File Size**: Check API file size limits (default: 4MB)
3. **File Types**: Only PDF, images, and documents allowed

### Common Errors

**"Connection refused"**
- Backend server is not running
- Wrong IP address in API base URL
- Firewall blocking connections

**"Token has expired"**
- Token expires after 24 hours
- Use refresh token endpoint or re-login

**"Invalid credentials"**
- Check username and password
- Ensure backend database is accessible

## Dependencies

- **http**: HTTP client for API calls
- **flutter_secure_storage**: Secure storage for auth tokens
- **provider**: State management
- **image_picker**: Image selection for Z reports
- **file_picker**: File selection for documents
- **intl**: Date and number formatting
- **shared_preferences**: Local storage
- **flutter_spinkit**: Loading indicators

## Screenshots

### Login Screen
- Username and password fields
- Material Design UI
- Loading indicator

### Home Screen
- Welcome message with user name
- Quick action cards for Z Reports and Cash Submit
- Logout button

### Z Reports Screen
- List of all Z reports
- Pull to refresh
- Floating action button to create new report
- Date, values A & C displayed

### Cash Submit Screen
- List of cash submissions
- Amount with currency formatting
- Supervisor information
- Date display
- Create new submission with supervisor selection

## License

Proprietary - Point of Sales Tanzania

## Support

For issues or questions, contact the development team.

---

**Version:** 1.0.0
**Last Updated:** October 18, 2025
**Built with Flutter ❤️**
