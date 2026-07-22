# ShelfSense

**A food spoilage risk-based inventory management system for reducing household food waste.**

ShelfSense is a mobile application that classifies each food item's spoilage risk (Low / Medium / High) using a machine-learning model, then helps the user prioritise what to consume first through a risk dashboard, recipe suggestions, and expiry notifications. It supports UN Sustainable Development Goal 12 (Responsible Consumption and Production).

---

## Architecture

ShelfSense has three parts that work together:

- **Flutter app** — the mobile client (`lib/`).
- **Python FastAPI backend** — serves the trained ML model (`ml_backend/`).
- **Firebase Firestore** — cloud storage for the user's inventory.

The app sends food-item attributes to the backend, which returns a spoilage-risk classification. If the backend is unreachable, the app falls back to an on-device heuristic, so it still works offline.

```
shelf_sense/
├── lib/                         # Flutter application source
│   └── services/ml_service.dart # <-- backend URL is configured here
├── android/                     # Android project files
├── pubspec.yaml                 # Flutter dependencies
│
└── ml_backend/                  # Python FastAPI ML service
    ├── main.py                  # API entry point (run this)
    ├── api/                     # schemas.py, predict.py (routing + inference)
    ├── model/                   # trained model artifacts (.pkl + category_stats.json)
    └── requirements.txt         # Python dependencies
```

---

## Prerequisites

Make sure the following are installed:

- **Flutter SDK** (with Dart) — for the mobile app
- **Android Studio** or **VS Code** with the Android SDK — to build/run on a device or emulator
- **JDK 17** — the Android build targets Java/Kotlin 17
- **Python 3.10+** — for the ML backend
- A **Firebase project** with Cloud Firestore and Anonymous Authentication enabled (already configured via `firebase_options.dart` and `google-services.json`)

---

## Setup & Run

The backend must be running **before** you launch the app, and both must be on the **same Wi-Fi network** when testing on a physical phone.

### Part A — Start the ML backend

1. Open a terminal in the backend folder:

   ```bash
   cd ml_backend
   ```

2. Create and activate a virtual environment:

   **Windows**
   ```bash
   python -m venv venv
   venv\Scripts\activate
   ```

   **macOS / Linux**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

3. Install dependencies:

   ```bash
   pip install -r requirements.txt
   ```

4. Confirm the trained model artifacts are present in `ml_backend/model/`:
   `spoilage_model.pkl`, `encoders.pkl`, `target_encoder.pkl`,
   `spoilage_model_noexpiry.pkl`, `encoders_noexpiry.pkl`, `target_encoder_noexpiry.pkl`,
   and `category_stats.json`.

5. Start the server (host `0.0.0.0` makes it reachable from your phone):

   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

6. Verify it's running by visiting **http://localhost:8000/docs** in a browser.
   You should see the interactive API docs. The health check at **http://localhost:8000/** returns `{"status": "ok"}`.

### Part B — Point the app at your backend

The app needs to know your computer's address on the network.

1. Find your computer's local IP address:
   - **Windows:** run `ipconfig` and read the **IPv4 Address** (e.g. `192.168.1.5`).
   - **macOS / Linux:** run `ifconfig` or `ip addr`.

2. Open `lib/services/ml_service.dart` and set `_baseUrl` to that address:

   ```dart
   static const String _baseUrl = "http://192.168.1.5:8000";
   ```

   Use the right host for your target:
   | Target | Base URL |
   |---|---|
   | Physical phone (same Wi-Fi) | `http://<your-PC-IPv4>:8000` |
   | Android emulator | `http://10.0.2.2:8000` |
   | Chrome / web | `http://localhost:8000` |

### Part C — Run the Flutter app

1. From the project root (`shelf_sense/`), fetch dependencies:

   ```bash
   flutter pub get
   ```

2. Connect a device (or start an emulator) and run:

   ```bash
   flutter run
   ```

   To build a release APK instead:

   ```bash
   flutter build apk --release
   ```

3. On first launch the app signs in anonymously to Firebase and syncs Firestore, then opens the dashboard. Add a food item and confirm its risk badge appears — that means the app reached the backend successfully.

---

## Troubleshooting

**The app shows risk levels, but they don't seem to come from the model.**
The app falls back to an on-device heuristic when it can't reach the backend. Check that the backend is running and that `_baseUrl` points to the correct IP. When the model is reached, predictions refresh on load and on pull-to-refresh.

**The phone can't reach the backend.**
- Confirm the phone and computer are on the **same Wi-Fi network**.
- Confirm the backend was started with `--host 0.0.0.0` (not the default `127.0.0.1`).
- Allow inbound connections on **port 8000** through your computer's firewall.
- Some campus/public Wi-Fi networks isolate devices from each other — if so, connect both devices to a personal mobile hotspot.

**`flutter run` fails to build.**
Confirm JDK 17 is installed and selected, and that `google-services.json` is present under `android/app/`.

---

## Tech Stack

Flutter (Dart) · Python · FastAPI · Uvicorn · XGBoost · scikit-learn · Firebase Firestore · Firebase Auth

## Machine Learning

The model is an XGBoost classifier trained offline on the Kaggle "Perishable Goods Management" dataset (89,880 records after cleaning). Two models sit behind a single `/predict` endpoint: a five-feature main model for items with an expiry date, and a four-feature no-expiry model for items without one. The API automatically routes to the correct model based on the request.
