# POS Tanzania Mobile App

Flutter mobile application for Point of Sales Tanzania system with multi-client support, Z Reports, Cash Submission, and comprehensive business management features.

## 🌟 Key Features

- **Multi-Client Support**: Single app supports 21+ different clients with dynamic API switching
- **Client Selector**: Easy-to-use interface to switch between clients
- **Authentication**: JWT-based login with secure token storage and biometric support
- **Z Reports**: View, create, and submit Z Reports with file attachments and stock location support
- **Cash Submissions**: Submit cash with supervisor approval workflow
- **Banking**: Track and manage banking transactions
- **Expenses**: Record and categorize business expenses
- **Sales Management**: Create, view, and manage sales with multiple payment types
- **Inventory**: Manage items, stock locations, and receivings
- **Customer/Supplier Credits**: Track credit accounts and payments
- **Contracts**: View and manage customer contracts
- **Offline Support**: Secure storage for authentication tokens
- **Tanzania-Specific**: TRA compliance features (Z Reports, EFD)
- **Glassmorphic UI**: Modern, beautiful user interface with dark mode support
- **Permission-Based Access**: Role-based access control for different features

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

### 3. Configure API Base URL (Optional)

**Note:** The app now uses a multi-client configuration system. You can select different clients from the app without changing code.

To update the development API URL for all clients, edit `lib/config/clients_config.dart`:

```dart
static const String localBaseUrl = 'http://172.16.245.29:8888/PointOfSalesTanzania/public/api';
```

**For Android Emulator:** Use `http://10.0.2.2:8888/`
**For iOS Simulator:** Use `http://localhost:8888/`
**For Physical Device:** Use your computer's local IP (e.g., `http://192.168.1.100:8888/`)

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

## 🏢 Multi-Client Configuration

This app supports multiple clients (21+ clients) with a single APK. Each client can have different backend servers.

### How to Use

1. **First Launch**: Select your client from the list
2. **Login**: Enter your credentials
3. **Switch Client**: Go to Settings → Switch Client

### Available Clients

SADA, Come & Save, Bonge, Iddy, Kassim, Leruma, Mazao, Meriwa, Pingo, PLM Store, POSTZ, Qatar, Ruge, Sanira, SGS, Shorasho, Shukuma, TrishBake, White Star, Zai, Zai Food

### Configuration

Client configurations are stored in `lib/config/clients_config.dart`. Each client has:
- **Development URL**: Used when running `flutter run`
- **Production URL**: Used when building release APK

**For detailed information**, see [CLIENT_CONFIGURATION.md](CLIENT_CONFIGURATION.md)

## Project Structure

```
lib/
├── main.dart                      # App entry point
├── config/                        # Configuration
│   └── clients_config.dart       # Multi-client configuration
├── models/                        # Data models
│   ├── api_response.dart
│   ├── client_config.dart        # Client model
│   ├── user.dart
│   ├── z_report.dart
│   ├── cash_submission.dart
│   ├── banking.dart
│   ├── expense.dart
│   ├── sale.dart
│   └── ... (more models)
├── providers/                     # State management
│   ├── auth_provider.dart
│   ├── permission_provider.dart
│   ├── location_provider.dart
│   └── theme_provider.dart
├── screens/                       # UI screens
│   ├── client_selector_screen.dart
│   ├── login_screen.dart
│   ├── home_screen.dart
│   ├── main_navigation.dart
│   ├── z_report/
│   ├── banking/
│   ├── expenses_screen.dart
│   ├── sales_screen.dart
│   └── ... (more screens)
├── services/                      # API services
│   ├── api_service.dart          # Main API service
│   └── biometric_service.dart
├── utils/                         # Utilities
│   ├── constants.dart
│   └── formatters.dart
└── widgets/                       # Reusable widgets
    ├── glassmorphic_card.dart
    ├── permission_wrapper.dart
    └── app_bottom_navigation.dart
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
