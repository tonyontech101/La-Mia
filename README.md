# La Mia — Discover, Cook, and Share Authentic Filipino Recipes 🍲

Welcome to **La Mia**, a modern Flutter application designed to showcase authentic Filipino cuisine. The project features 200+ detailed recipes, an ingredient pricing catalog, interactive search, dynamic category filtering, and real-time backend synchronization powered by Firebase.

---

> ⚠️ **SECURITY FIRST**  
> Sensitive credential files (`serviceAccountKey.json`, `google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart`) are **strictly excluded from Git** via `.gitignore` to prevent secret leaks. Please follow the instructions below to configure your local setup.

---

## 🏗️ Tech Stack & Architecture

- **Frontend**: [Flutter](https://flutter.dev/) (Dart 3.x) with Material 3 & Custom Design Tokens
- **Database**: [Cloud Firestore](https://firebase.google.com/docs/firestore) (Recipes & Ingredient Catalog)
- **Storage**: [Firebase Cloud Storage](https://firebase.google.com/docs/storage) (Hosted Recipe Cover Photos)
- **Authentication**: [Firebase Auth](https://firebase.google.com/docs/auth) (Email/Password & Google Sign-In)
- **Seed Utility**: [Node.js](https://nodejs.org/) + `firebase-admin` SDK

> 📌 **Architecture status**: The full target architecture (Riverpod state
> management, go_router declarative navigation, Cloud Functions for the
> ingredient-matching engine, App Check, flavors, and CI) is described in
> `La Mia - Architecture (Flutter + Firebase).md` and is **planned but not
> yet implemented**. The current codebase uses `StatefulWidget` + imperative
> `Navigator` and ships the UI scaffolding for the features below. See
> `implementation_plan.md` for the build order.

---

## 📁 Repository Structure

```text
LaMia/
├── lamia_app/                  # Core Flutter Application
│   ├── android/                # Android native project files
│   ├── ios/                    # iOS native project files
│   ├── assets/                 # App icons, static images & assets
│   ├── lib/
│   │   ├── app/                # App root widget, theme tokens & design system
│   │   ├── core/               # Shared constants, utils & reusable UI states
│   │   ├── features/
│   │   │   ├── auth/           # Login, Sign-up & AuthService (Firebase Auth)
│   │   │   ├── home/           # Dashboard, Feed, Search & navigation shell
│   │   │   ├── recipes/        # Recipe Model, Firestore Repository & Cook-by-Ingredients
│   │   │   ├── profile/        # User profile screen, tab grid & header widget  (planned stats)
│   │   │   └── leaderboard/    # Chef ranking screen  (currently demo data)
│   │   └── main.dart           # Application entry point
│   ├── test/                   # Unit + widget tests (Validators, AuthErrorMessages, IngredientMatcher, LoginScreen)
│   ├── firestore.rules         # Firestore security rules (deploy with `firebase deploy --only firestore:rules`)
│   ├── firestore.indexes.json  # Composite indexes for RecipeRepository queries
│   ├── storage.rules           # Cloud Storage security rules
│   ├── firebase.json           # Firebase CLI config (project + rules + indexes wiring)
│   └── pubspec.yaml            # Flutter dependencies & configuration
│
├── recipes/                    # Local Recipe Dataset (200 recipes in 13 categories)
│   ├── almusal/
│   ├── ulam/
│   └── ...
│
└── tools/                      # Node.js Database Seeding Tools
    ├── seed_recipes.js         # Main seeding script (Firestore + Cloud Storage)
    ├── seed_featured.js        # Featured & Popularity initial ranking script
    ├── package.json            # Node.js dependencies (`firebase-admin`)
    └── serviceAccountKey.json.example  # Template for Firebase Admin key
```

---

## 🛠️ Prerequisites

Before getting started, make sure your machine has the following tools installed:

1. **Flutter SDK** (v3.12 or later) — [Install Guide](https://docs.flutter.dev/get-started/install)
2. **Node.js** (v18 or later) — [Install Guide](https://nodejs.org/)
3. **Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```
4. **FlutterFire CLI**:
   ```bash
   dart pub global activate flutterfire_cli
   ```

---

## 🚀 Step-by-Step Developer Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/tonyontech101/La-Mia.git
cd LaMia
```

---

### Step 2: Install Flutter Dependencies

Navigate to the `lamia_app` directory and fetch the required packages:

```bash
cd lamia_app
flutter pub get
```

---

### Step 3: Firebase Client Configuration

> 💡 **COLLABORATOR NOTE**:  
> If your team lead has already provided the pre-configured project credentials (`google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart`), place them in the locations listed in **Option B** and **skip Step 3**.

Otherwise, connect your local app to the team's Firebase project using one of the options below:

#### Option A: Automatic Setup via FlutterFire CLI (Recommended)

1. Log in to your Firebase account:
   ```bash
   firebase login
   ```
2. Run FlutterFire CLI inside `lamia_app/`:
   ```bash
   flutterfire configure
   ```
3. Select your Firebase project (`la-mia-e348d`) and target platforms (Android, iOS, Web).  
   *This automatically generates `lib/firebase_options.dart` without committing secrets to Git.*

#### Option B: Manual Configuration

Obtain the files from the Firebase Console or project lead:

1. **Android**: Download `google-services.json` (Project Settings → Android) and place in:
   ```text
   lamia_app/android/app/google-services.json
   ```
2. **iOS**: Download `GoogleService-Info.plist` (Project Settings → iOS) and place in:
   ```text
   lamia_app/ios/Runner/GoogleService-Info.plist
   ```
3. **Flutter Options**: Copy the template file:
   ```bash
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   ```
   Open `lib/firebase_options.dart` and fill in your project credentials.

---

### Step 4: Seed Database & Storage (`tools/`)

To populate Cloud Firestore and Cloud Storage with the 200 recipes and ingredient pricing catalog:

1. **Download Service Account Key**:
   - Go to [Firebase Console](https://console.firebase.google.com/) → **Project Settings** ⚙️ → **Service accounts**.
   - Click **Generate new private key** (downloads a `.json` file).
   - Move the file to `tools/` and rename it to `serviceAccountKey.json`.

2. **Run Seeding Scripts**:
   ```bash
   cd tools
   npm install

   # Dry Run (Preview only — no writes to Firebase)
   npm run seed:dry

   # Live Seed (Uploads images to Cloud Storage & populates Firestore)
   node seed_recipes.js

   # Seed Featured & Popularity Scores
   node seed_featured.js
   ```

> ℹ️ **Seeding Behavior**:
> - **Idempotent**: Re-running scripts will update existing Firestore documents without duplicating data.
> - **Storage Optimization**: Images already present in Cloud Storage are reused automatically to avoid unnecessary bandwidth usage.

---

### Step 5: Run the Application

With configuration complete, launch the app on your emulator or physical device:

```bash
cd lamia_app
flutter run
```

---

## ❓ Troubleshooting & FAQs

<details>
<summary><b>1. PowerShell script error on Windows: <code>npm.ps1 cannot be loaded</code></b></summary>
<br/>
Windows PowerShell blocks `.ps1` script execution by default. To bypass this, run node scripts directly:
```bash
node seed_recipes.js
```
or run PowerShell as Administrator and execute:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
</details>

<details>
<summary><b>2. Firebase Error: <code>Bucket name not specified or invalid</code></b></summary>
<br/>
The seed script automatically infers your storage bucket (`<project_id>.firebasestorage.app`) from `serviceAccountKey.json`. If using a custom bucket, set the environment variable:
```bash
STORAGE_BUCKET=my-custom-bucket node seed_recipes.js
```
</details>

<details>
<summary><b>3. Missing asset directory errors in Flutter terminal</b></summary>
<br/>
If you see asset path warnings, ensure `pubspec.yaml` only lists existing folders (`assets/images/`). Cover photos for recipes are loaded via network URLs (`CachedNetworkImage`).
</details>

---

## 🔒 Security & Contribution Checklist

Before submitting a Pull Request or pushing commits to GitHub:

- [x] Verify secret files (`serviceAccountKey.json`, `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) are ignored by `git status`.
- [x] Do NOT force-add (`git add -f`) any credential files.
- [x] Run `flutter analyze` inside `lamia_app/` to ensure no syntax or lint errors.
