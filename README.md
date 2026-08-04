# Jimmy

A personal health and habit tracking app for iPhone and iPad, built with SwiftUI and SwiftData.

## Features

- **Fasting** — live fasting timer with session history, plus a calendar of completed fasting days (16+ hour fasts auto-complete the day)
- **Workouts & Exercises** — log gym days and track individual exercises with sets, reps, and weight
- **Drinks & Sauna** — simple daily habit calendars
- **Body Measurements** — track any measurement type over time
- **Apple Health** — reads weight and step count to show trends alongside your habits
- **Judgement Day** — optional countdown to a goal date of your choosing, configurable in Settings
- **iCloud sync** — data syncs across devices via your private CloudKit database; workout data can also be exported to iCloud Drive

## Requirements

- Xcode 16 or later
- iOS 18.2 or later

## Building

Open `Jimmy.xcodeproj` in Xcode and run the `Jimmy` scheme. HealthKit and CloudKit entitlements require a development team with those capabilities enabled; the app falls back to local-only storage when CloudKit is unavailable.

## Privacy

All data stays on device and in the user's private iCloud account — no analytics, no third-party services, no developer-accessible servers. See the [privacy policy](https://schacon.github.io/jimmy/privacy.html).

The `docs/` directory is the GitHub Pages site: a landing page at `index.html` and the privacy policy at `privacy.html`.
