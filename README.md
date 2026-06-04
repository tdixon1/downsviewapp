# Downsview SDA Flutter Port

This is the first Flutter port of the Expo app. The existing Expo app is left intact in the repo root.

## Setup

Install Flutter, then from `flutter_app` run:

```powershell
flutter pub get
flutter create --platforms=android,ios .
flutter run --dart-define=SUPABASE_URL=https://eyxavkbymfikzubomllx.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

The Supabase values intentionally come from `--dart-define` so production keys are not committed into Dart source.

## Ported In This Pass

- Supabase auth with guest mode
- Bottom-tab shell with role-gated Team tab
- Home dashboard with sermons, bulletin, events, lessons, and giving
- Info/news screen with WordPress posts and bookmarks
- Response/appeals screen with guest contact handling and sermon notes
- Profile editing with Supabase metadata/profile upsert and avatar upload
- Team screen basics for follow-ups, attendance export, members, and queued push messages
- WordPress and Adventech Sabbath School service ports
- Calendar and notification service facades

## Native Follow-Ups

These need Flutter native project files before they can be finished:

- Android/iOS permissions for notifications, calendar, camera, and photos
- Firebase config files for push notifications
- Exact recurring local notification scheduling with timezone initialization
- App icons, splash screen, bundle id/package id, signing, and store build config

## Shorebird

Add Shorebird after the Flutter app builds cleanly and before the first production Flutter release. It will help patch Dart/UI/Supabase workflow fixes quickly, but native permission/plugin changes still require store releases.
