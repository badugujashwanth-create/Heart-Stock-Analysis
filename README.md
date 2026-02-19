# HeartAnalysis

HeartAnalysis is a cross platform Flutter application that helps people capture clinical and lifestyle factors, call an AI powered prediction API, and receive an interpretable heart stroke risk report. The app ships with onboarding, local only authentication, a multi tab experience, a health assistant, PDF exports, and basic settings so it can be demoed on mobile, web, or desktop.

## Features

- Guided onboarding and lightweight email plus password auth (stored locally with `SharedPreferences` for demo purposes).
- Rich prediction form with 18 inputs, client side BMI calculation, draft persistence, and validation before submitting to the `/predict` backend.
- Result screen that normalizes API responses, surfaces personalized recommendations, caches the outcome for the assistant, and exports a printable PDF via the `pdf` and `printing` packages.
- Health Assistant tab that emulates a rule based chat bot, keeps history on device, and links back to the last prediction so users can ask follow up questions.
- Recommended tips, configurable notifications, profile editing, and simple privacy/help/about pages under the Settings tab.
- Light and dark theming plus Material 3 components for consistent styling across Android, iOS, Web, Windows, macOS, and Linux builds.

## Architecture at a Glance

| Layer | Responsibilities | Key Files |
| --- | --- | --- |
| App shell | Boots Flutter, picks theme, routes based on onboarding/auth state | `lib/main.dart`, `lib/theme/app_theme.dart` |
| Screens | Onboarding, auth, multi tab experience, form, assistant, result, settings | `lib/screens/**/*.dart` |
| Services | Local auth facade with `SharedPreferences` | `lib/services/auth_service.dart` |
| Utilities & Widgets | Form styling helpers and reusable UI atoms | `lib/utils/ui.dart`, `lib/widgets/*` |

The runtime flow is:

1. `_RootDecider` in `main.dart` checks if the user finished onboarding and login; it then routes to `OnboardingScreen`, `LoginScreen`, or the `MainAppScreen` tab scaffold.
2. `MainAppScreen` lazily builds four tabs: `HomeScreen` (prediction form), `RecommendedTipsScreen`, `HealthAssistantScreen`, and `SettingsScreen`.
3. `HomeScreen` collects inputs, autosaves drafts, and posts JSON to `${apiBaseUrl}/predict`. Successful responses navigate to `PredictionResultScreen`.
4. `PredictionResultScreen` persists the normalized risk to `SharedPreferences` for the assistant, shows recommendations, and can generate a PDF.
5. `HealthAssistantScreen` reads `last_prediction` to answer "Explain my result" questions and stores chat history locally.

## Directory Structure

```
lib/
|-- config.dart                 # API base URL (`apiBaseUrl`)
|-- main.dart                   # App entry point and root routing logic
|-- screens/
|   |-- onboarding_screen.dart
|   |-- login_screen.dart
|   |-- register_screen.dart
|   |-- main_app_screen.dart    # Bottom navigation scaffold
|   |-- home_screen.dart        # Prediction form + API call
|   |-- prediction_result_screen.dart
|   |-- assistant_screen.dart
|   |-- tips_screen.dart
|   `-- settings/
|       |-- settings_screen.dart
|       |-- profile_screen.dart
|       |-- notifications_screen.dart
|       |-- privacy_screen.dart
|       |-- help_screen.dart
|       `-- about_screen.dart
|-- services/
|   `-- auth_service.dart
|-- theme/
|   `-- app_theme.dart
|-- utils/
|   `-- ui.dart
`-- widgets/
    |-- header.dart
    `-- tip_card.dart
```

## Configuration

- API endpoint: update `lib/config.dart` to point at your backend (defaults to `https://stroke-app-as3q.onrender.com`).
- Prediction timeout: `HomeScreen._getPrediction` currently times out after 25 seconds. Adjust if your server is slower/faster.
- Local storage keys: `AuthService` and various screens rely on specific keys (`user_name`, `last_prediction`, `form_draft_v1`, etc.). If you change them, update both the read and write sites.

## Prediction API Contract

- Endpoint: `POST {apiBaseUrl}/predict`
- Headers: `Content-Type: application/json`
- Request body

| Field | Type | Source |
| --- | --- | --- |
| `age` | int | `Age` text field |
| `gender` | string (`Male`, `Female`, `Other`) | Gender dropdown |
| `hypertension`, `heart_disease`, `alcoholic`, `family_history`, `excess_salt` | string (`Yes` or `No`) | Yes/No selectors |
| `ever_married` | string (`Yes` or `No`) | Marital status selector |
| `work_type` | string (`Private`, `Self-employed`, `Govt`, `Children`, `Never worked`) | Work dropdown |
| `Residence_type` | string (`Urban` or `Rural`) | Residence dropdown |
| `avg_glucose_level`, `bmi` | double | Calculated text inputs |
| `systolic_bp`, `diastolic_bp`, `sleep_hours`, `exercise_mins` | int | Numeric inputs |
| `smoking_status` | string (`Never`, `Formerly`, `Smokes`) | Dropdown mapped from UI labels |

- Response expectations: The app handles either `{ stroke_prediction: <0-1>, risk_label: "High Risk" }` or a list containing that map. Probabilities over 1 are treated as percentages and normalized to a 0-1 fraction.

## Local Persistence

| Key | Owner | Purpose |
| --- | --- | --- |
| `onboarded` | `OnboardingScreen` | Skip onboarding after first run |
| `is_logged_in`, `user_email`, `user_name` | `AuthService` | Simple auth state and profile |
| `form_draft_v1` | `HomeScreen` | Autosaved prediction form draft |
| `last_prediction`, `last_prediction_time` | `PredictionResultScreen` | Last risk value for assistant |
| `chat_history_v1` | `HealthAssistantScreen` | Stored assistant conversation |
| `notif_enabled` | `NotificationsScreen` | Local notification toggle |

## Running the App

```bash
flutter pub get          # Install dependencies
flutter analyze          # Static analysis (optional but recommended)
flutter test             # Widget/unit tests (none yet, command succeeds)
flutter run              # Launch on the default connected device
```

Target a platform explicitly with `flutter run -d android`, `-d ios`, `-d chrome`, etc. When you are ready to ship, follow the platform specific steps in `DEPLOYMENT.md`.

## Testing and Linting

- Analyzer rules are defined in `analysis_options.yaml` (Flutter lints v2). Run `flutter analyze` to catch issues before committing.
- No bespoke widget or integration tests exist yet; add them under `test/` as you extend the app.

## Deployment

`DEPLOYMENT.md` documents how to build signed Android App Bundles/APKs, iOS IPAs, and desktop/web releases, plus a sample GitHub Actions workflow. Refer to that file for store ready builds.

## Roadmap Ideas

- Replace the local `AuthService` with a real backend or Firebase Auth.
- Add offline queueing/retry when the prediction API is unavailable.
- Expand test coverage (widget tests for the form and assistant, integration tests for navigation).
- Internationalization and accessibility reviews.
