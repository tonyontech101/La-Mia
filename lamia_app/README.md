# La Mia — Flutter Mobile Application 🍲

This directory contains the core Flutter mobile client for **La Mia**, an authentic Filipino recipe discovery app built with Flutter (Dart 3.x) and Firebase.

---

## 📖 Application Overview & Documentation

For full details on features, architecture, database seeding, and project structure, please consult the primary project documentation:

👉 **[Complete Project Documentation & Setup Guide](../README.md)**

---

## ⚡ Quick Start (Flutter App)

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Configure Firebase
Generate `lib/firebase_options.dart` using FlutterFire CLI:
```bash
flutterfire configure
```
*(If manual config is required, see `lib/firebase_options.dart.example` or refer to the [Root Setup Guide](../README.md)).*

### 3. Launch Application
```bash
flutter run
```

---

## 🧪 Testing & Code Quality

Run tests and static analysis before submitting changes:

```bash
# Run unit and widget tests
flutter test

# Run static analysis
flutter analyze
```
