# Leruma POS Mobile App - Deployment Documentation

## App Information

| Field | Value |
|-------|-------|
| **App Name** | Leruma POS |
| **Package Name** | co.tz.leruma.pos |
| **Version** | 1.0.0 |
| **Developer** | Leruma Enterprises |
| **Platform** | Android |
| **Min SDK** | Android 5.0 (API 21) |
| **Target SDK** | Android 15 (API 35) |

---

## Play Store Listing

### Short Description (80 chars max)
```
Point of Sale system for sales, inventory, credits & reports management.
```

### Category
- **Primary:** Business
- **Tags:** POS, Point of Sale, Inventory, Sales, Stock Management, Business, Tanzania, Credits, Accounting, Reports, Retail, Wholesale

### Privacy Policy URL
```
https://leruma.co.tz/policy
```

### Contact Information
- **Email:** info@lerumaenterprises.co.tz
- **Address:** Dar es Salaam, Tanzania

---

## App Features

### Core Modules
1. **Sales Management**
   - Process sales quickly
   - View sales history
   - Handle suspended sales
   - Multiple payment methods

2. **Inventory & Stock**
   - Real-time stock tracking
   - Multi-location support
   - Stock movements
   - Item pricing management

3. **Customer Credits**
   - Customer credit accounts
   - Credit statements
   - Payment recording
   - Daily debt reports

4. **Supplier Credits**
   - Supplier credit tracking
   - Payment management
   - Credit reports

5. **Reports**
   - Z-Reports (daily summaries)
   - Sales reports by date
   - Stock tracking reports
   - Profit analysis

6. **Financial Operations**
   - Cash submission tracking
   - Banking records
   - Expense recording

---

## Build Configuration

### Keystore Information
| Field | Value |
|-------|-------|
| **Keystore File** | `android/app/upload-keystore.jks` |
| **Key Alias** | upload |
| **Keystore Password** | Leruma2024 |
| **Key Password** | Leruma2024 |
| **Validity** | 10,000 days |

### Build Commands

**Debug APK:**
```bash
cd /Applications/MAMP/htdocs/pos_tanzania_mobile
flutter build apk --flavor leruma --debug
```

**Release APK:**
```bash
flutter build apk --flavor leruma --release
```

**Release AAB (for Play Store):**
```bash
flutter build appbundle --flavor leruma --release
```

### Build Output Locations
- **Debug APK:** `build/app/outputs/flutter-apk/app-leruma-debug.apk`
- **Release APK:** `build/app/outputs/flutter-apk/app-leruma-release.apk`
- **Release AAB:** `build/app/outputs/bundle/lerumaRelease/app-leruma-release.aab`

---

## Project Structure

```
pos_tanzania_mobile/
├── android/
│   ├── app/
│   │   ├── build.gradle.kts          # App build config with signing
│   │   ├── upload-keystore.jks       # Release signing keystore
│   │   └── src/
│   │       └── leruma/
│   │           └── res/              # Leruma-specific resources
│   │               └── mipmap-*/     # App icons
│   └── key.properties                # Keystore credentials
├── lib/
│   ├── main.dart                     # App entry point
│   ├── models/                       # Data models
│   │   ├── permission_model.dart
│   │   ├── supplier_credit.dart
│   │   └── ...
│   ├── screens/                      # UI screens
│   │   ├── customer_credit_screen.dart
│   │   ├── suppliers_credits_screen.dart
│   │   ├── main_navigation.dart
│   │   └── ...
│   ├── services/                     # API services
│   │   └── api_service.dart
│   └── widgets/                      # Reusable widgets
├── playstore_assets/                 # Play Store materials
│   ├── app_icon_512.png              # Store icon
│   ├── store_listing.txt             # Descriptions
│   └── privacy_policy.html           # Privacy policy backup
└── pubspec.yaml                      # Dependencies
```

---

## Product Flavors

The app supports multiple client builds:

| Flavor | Package Name | App Name |
|--------|--------------|----------|
| leruma | co.tz.leruma.pos | Leruma POS |
| sada | co.tz.sada.pos | SADA POS |
| comeAndSave | co.tz.comeandsave.pos | Come & Save POS |

---

## API Configuration

### Backend Server
- **URL:** https://leruma.co.tz
- **API Base:** https://leruma.co.tz/api/

### Key API Endpoints
| Endpoint | Description |
|----------|-------------|
| `/api/login` | User authentication |
| `/api/sales` | Sales operations |
| `/api/items` | Inventory management |
| `/api/customers` | Customer management |
| `/api/suppliers_creditors` | Supplier credits |
| `/api/credits` | Customer credits |
| `/api/reports` | Business reports |

---

## Permissions Used

### Android Permissions
- `INTERNET` - Network access
- `ACCESS_NETWORK_STATE` - Check connectivity
- `CAMERA` - Barcode scanning
- `WRITE_EXTERNAL_STORAGE` - Export reports

### App Permissions (Role-based)
| Permission ID | Description |
|---------------|-------------|
| `credits_pay` | Customer credit payments |
| `credits_edit_date` | Edit customer payment date |
| `suppliers_creditors_make_payment` | Supplier payments |
| `suppliers_creditors_edit_date` | Edit supplier payment date |

---

## Play Store Deployment Status

### Requirements Checklist
- [x] App Bundle (AAB) built and signed
- [x] App icon (512x512)
- [x] Screenshots uploaded
- [x] Feature graphic created
- [x] Short description
- [x] Full description
- [x] Privacy policy URL
- [x] Content rating completed
- [x] App content declarations
- [x] Test credentials provided
- [ ] Developer account verified
- [ ] Internal testing release published
- [ ] Closed testing (12 testers, 14 days)
- [ ] Production release

### Account Verification
- **Status:** Pending
- **Required:** Identity verification + Phone verification
- **Note:** Phone verification unlocks after identity is approved

---

## Test Credentials (for Google Review)

```
Server URL: https://leruma.co.tz
Username: admin
Password: ilovemywife
```

---

## Support & Contact

- **Developer:** Leruma Enterprises
- **Email:** info@lerumaenterprises.co.tz
- **Website:** https://leruma.co.tz

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | January 2025 | Initial release |

---

## Important Notes

1. **Keystore Backup:** Keep `upload-keystore.jks` safe - you cannot update the app without it
2. **Play App Signing:** Google manages the app signing key after first upload
3. **Testing:** Complete 14-day closed testing before production access
4. **Updates:** Increment `versionCode` in `pubspec.yaml` for each update

---

*Document generated: January 16, 2025*