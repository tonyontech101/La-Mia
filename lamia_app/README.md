# La Mia — Flutter Mobile Application

This directory contains the main Flutter mobile application code for **La Mia**.

## 🚀 Setup & Firebase Configuration

Secret credentials and configuration files are excluded from Git repository to protect sensitive project keys.

Before running the application for the first time, refer to the project root documentation:
👉 **[Root Setup Guide](../README.md)**

### Quick Firebase Setup (FlutterFire CLI)

```bash
# 1. Install dependencies
flutter pub get

# 2. Configure Firebase (generates lib/firebase_options.dart locally)
flutterfire configure

# 3. Run app
flutter run
```

Refer to `lib/firebase_options.dart.example` if manual configuration is required.
