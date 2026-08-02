# La Mia — Setup & Developer Guide

Welcome to the **La Mia** repository! This project consists of the main Flutter mobile application (`lamia_app/`) and backend seed utilities (`tools/`).

> ⚠️ **IMPORTANT SECURITY NOTE**  
> Secret credential files (`serviceAccountKey.json`, `google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart`) are excluded from Git repository via `.gitignore` to prevent sensitive credentials from leaking into source control.  
> Follow the setup guide below to configure your local development environment.

---

## 📁 Repository Structure

- `lamia_app/` — Flutter mobile application for iOS & Android.
- `tools/` — Node.js utility scripts (e.g., seeding Firestore with initial recipe data).

---

## 🛠️ Prerequisites

Before you begin, ensure you have the following installed on your development machine:

1. [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or later)
2. [Node.js](https://nodejs.org/) (v18 or later)
3. [Firebase CLI](https://firebase.google.com/docs/cli)
   ```bash
   npm install -g firebase-tools
   ```
4. [FlutterFire CLI](https://firebase.google.com/docs/cli#flutter)
   ```bash
   dart pub global activate flutterfire_cli
   ```

---

## 🚀 Step-by-Step Teammate Setup Guide

### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd LaMia
```

---

### Step 2: Set Up the Flutter App (`lamia_app`)

1. Navigate to the app directory:
   ```bash
   cd lamia_app
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```

---

### Step 3: Firebase Client Configuration

> 💡 **Note**: If you have already received access to Firebase collaboration and have been provided with the pre-configured project files (`google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart`), you can **skip Step 3**!

To run the Flutter app, you must connect it to the team's Firebase project using **one of the two options below**:

#### Option A: Automatic Configuration via FlutterFire CLI (Recommended)

1. Log in to Firebase CLI:
   ```bash
   firebase login
   ```
2. Run FlutterFire CLI inside the `lamia_app/` directory:
   ```bash
   flutterfire configure
   ```
3. Select your Firebase project and platforms (Android/iOS).  
   *This automatically generates `lib/firebase_options.dart` and the native platform configuration files on your machine without committing them to Git.*

#### Option B: Manual Configuration

If you do not use FlutterFire CLI, obtain the configuration files from the Firebase Console or project lead:

1. **Android**: Download `google-services.json` from Firebase Console (Project Settings → General → Android App) and place it in:
   ```
   lamia_app/android/app/google-services.json
   ```
2. **iOS**: Download `GoogleService-Info.plist` from Firebase Console (Project Settings → General → iOS App) and place it in:
   ```
   lamia_app/ios/Runner/GoogleService-Info.plist
   ```
3. **Flutter Options**: Copy the example template file:
   ```bash
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   ```
   Open `lib/firebase_options.dart` and replace the placeholder strings (`YOUR_ANDROID_API_KEY`, `YOUR_PROJECT_ID`, etc.) with your actual project keys.

---

### Step 4: Set Up Database Seed Script (`tools/`)

If you need to seed initial recipe data into Cloud Firestore:

1. **Obtain Firebase Admin Service Account Key**:
   - Go to [Firebase Console](https://console.firebase.google.com/).
   - Go to **Project Settings** ⚙️ → **Service accounts**.
   - Click **Generate new private key** (downloads a `.json` file).

2. **Place Key in `tools/` directory**:
   - Copy the downloaded JSON file to `tools/` and rename it to `serviceAccountKey.json`.
   - Alternatively, copy the template:
     ```bash
     cp tools/serviceAccountKey.json.example tools/serviceAccountKey.json
     ```
     and replace its contents with your service account JSON.

3. **Run the Seed Script**:
   ```bash
   cd tools
   npm install
   npm run seed
   ```

---

### Step 5: Run the Flutter Application

Once Firebase options are configured:

```bash
cd lamia_app
flutter run
```

---

## 🔒 Security Checklist for Developers

- [ ] Run `git status` before pushing changes to verify no secret files (`serviceAccountKey.json`, `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) are being tracked.
- [ ] Never force-add (`git add -f`) ignored credential files.
- [ ] If you need to share service account keys with new team members, use a secure password manager (e.g. 1Password, Bitwarden) instead of sending files over chat or email.
