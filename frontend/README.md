# HeartAnalysis Frontend

Flutter client for the HeartAnalysis backend.

## Setup

```bash
cp .env.example .env
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8000
```

## Environment

`.env`:

```env
API_BASE_URL=http://localhost:8000
```

For release and CI builds, prefer compile-time configuration instead of `.env`:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://your-backend-host
```

## Checks

```bash
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
```
