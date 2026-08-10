# La Mia — Discover, Cook, and Share Authentic Filipino Recipes 🍲

**La Mia** is a modern Flutter mobile application built to celebrate and explore authentic Filipino cuisine. Designed with rich Material 3 UI aesthetics and real-time backend synchronization via Firebase, **La Mia** empowers home cooks, food enthusiasts, and culinary explorers to discover traditional dishes, match recipes based on available pantry ingredients, decide daily meals, and connect with a community of passion-driven chefs.

---

## 📱 What is La Mia?

Finding what to cook or managing kitchen ingredients can be challenging. **La Mia** solves this by combining rich culinary content with smart utility tools:

- 🍳 **200+ Authentic Filipino Recipes**: Access a rich, curated dataset spanning 13 traditional dish categories—including *Almusal*, *Ulam*, *Sabaw*, *Merienda*, *Pang-himagas*, *Pulutan*, and regional specialties.
- 🛒 **Cook-by-Ingredients (Pantry Matcher)**: Enter ingredients you currently have at home to instantly discover recipes you can make, complete with ingredient matching percentages and estimated market costs.
- 🎲 **"Ano Pong Ulam?" Meal Decision Helper**: Can't decide what to eat today? Use the interactive decision tool to get instant meal suggestions tailored to your mood or preferences.
- 🏆 **Community & Chef Leaderboard**: Celebrate top home chefs and discover community-favorite recipes through rankings and monthly featured chefs.
- 👤 **User Profiles & Bookmarks**: Save your favorite dishes, track your cooking history, and manage your culinary profile.

---

## 🏗️ Tech Stack & Architecture

- **Frontend Framework**: [Flutter](https://flutter.dev/) (Dart 3.x) with Material 3 styling and custom design tokens.
- **Backend & Database**: [Cloud Firestore](https://firebase.google.com/docs/firestore) for real-time recipe and user data storage.
- **Media Storage**: [Firebase Cloud Storage](https://firebase.google.com/docs/storage) for hosted high-resolution recipe cover photos.
- **Authentication**: [Firebase Auth](https://firebase.google.com/docs/auth) (Email/Password & Google Sign-In support).
- **Data Seeding Utilities**: [Node.js](https://nodejs.org/) script runner using `firebase-admin` SDK for uploading recipes and ingredient catalogs.

---

## 📁 Repository Structure

```text
LaMia/
├── lamia_app/                  # Core Flutter Mobile Application
│   ├── android/                # Android native project files
│   ├── ios/                    # iOS native project files
│   ├── assets/                 # Icons, static branding & app assets
│   ├── lib/
│   │   ├── app/                # App entry theme tokens & global design system
│   │   ├── core/               # Shared constants, utilities & reusable UI widgets
│   │   ├── features/
│   │   │   ├── auth/           # Login, Registration & Firebase AuthService
│   │   │   ├── home/           # Main Dashboard, Feed, Search & Navigation Shell
│   │   │   ├── recipes/        # Recipe Data Models, Firestore Repositories, Detail Screen & Pantry Matcher
│   │   │   ├── profile/        # User Profile Screen, Saved Bookmarks & Settings
│   │   │   └── leaderboard/    # Chef Rankings & Top Contributors
│   │   └── main.dart           # App Entry Point & Firebase initialization
│   ├── test/                   # Unit & Widget tests
│   ├── firestore.rules         # Security rules for Cloud Firestore
│   ├── firestore.indexes.json  # Composite query indexes for Firestore
│   ├── storage.rules           # Cloud Storage security rules
│   ├── firebase.json           # Firebase CLI configuration
│   └── pubspec.yaml            # Flutter packages & asset configuration
│
├── recipes/                    # Raw Local Recipe Dataset (200 recipes in 13 categories)
│   ├── almusal/
│   ├── ulam/
│   └── ...
│
└── tools/                      # Node.js Database & Storage Seeding Utilities
    ├── seed_recipes.js         # Main seeding script (Firestore + Storage upload)
    ├── seed_featured.js        # Initial score & popularity ranking script
    └── package.json            # Tooling dependencies (`firebase-admin`)
```

---

## 🛠️ Prerequisites

Ensure your development environment has the following tools installed before setting up the project:

1. **Flutter SDK** (v3.12 or higher) — [Install Flutter](https://docs.flutter.dev/get-started/install)
2. **Node.js** (v18 or higher) — [Install Node.js](https://nodejs.org/)
3. **Firebase CLI**:
   ```bash
   npm install -g firebase-tools
   ```
4. **FlutterFire CLI**:
   ```bash
   dart pub global activate flutterfire_cli
   ```

---

## 🚀 Step-by-Step Installation & Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/tonyontech101/La-Mia.git
cd LaMia
```

---

### Step 2: Install Flutter Dependencies

Navigate into the Flutter application folder and fetch the dependencies:

```bash
cd lamia_app
flutter pub get
```

---

### Step 3: Firebase Configuration

> 💡 **Collaborator Note**:  
> If you have received the official environment configuration files (`google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart`) from your project administrator, place them in their respective locations listed under **Option B** and skip to Step 4.

Otherwise, set up Firebase connection using one of the options below:

#### Option A: Automatic Setup via FlutterFire CLI (Recommended)

1. Log in to Firebase:
   ```bash
   firebase login
   ```
2. Run FlutterFire CLI inside `lamia_app/`:
   ```bash
   flutterfire configure
   ```
3. Select your Firebase project and target platforms (Android, iOS, Web). This generates `lib/firebase_options.dart` automatically.

#### Option B: Manual Setup

1. **Android**: Download `google-services.json` from the Firebase Console and place it at:
   ```text
   lamia_app/android/app/google-services.json
   ```
2. **iOS**: Download `GoogleService-Info.plist` from the Firebase Console and place it at:
   ```text
   lamia_app/ios/Runner/GoogleService-Info.plist
   ```
3. **Flutter Options**: Copy the template file and fill in your keys:
   ```bash
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   ```

---

### Step 4: Seed Database & Storage (`tools/`)

To populate Cloud Firestore and Cloud Storage with the 200+ recipes and ingredient catalog:

1. Obtain `serviceAccountKey.json` from **Firebase Console** → **Project Settings** ⚙️ → **Service accounts** → **Generate new private key**.
2. Save the key file to `tools/serviceAccountKey.json`.
3. Run the seed tools:
   ```bash
   cd ../tools
   npm install

   # Preview mode (dry-run without modifying database)
   npm run seed:dry

   # Upload recipe data & images to Firebase
   node seed_recipes.js

   # Generate featured and popularity ranking scores
   node seed_featured.js
   ```

---

### Step 5: Run the Mobile Application

Start an emulator or connect a physical device, then launch the Flutter app:

```bash
cd ../lamia_app
flutter run
```

---

## 🔒 Security & Best Practices

- 🛑 **Never commit secrets**: `serviceAccountKey.json`, `google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart` are ignored in `.gitignore`.
- 🔍 **Code Quality**: Always run `flutter analyze` inside `lamia_app/` before creating pull requests.
- 🔐 **Security Rules**: Deploy updated Firestore rules using `firebase deploy --only firestore:rules`.

---

## 🤝 Contributing & Support

Contributions are welcome! If you encounter issues or have suggestions:
1. Open an issue on GitHub.
2. Ensure your proposed code follows existing architecture and passes all lint checks (`flutter test` and `flutter analyze`).
