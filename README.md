# 🎵 Smart Music Player — Flutter App

A fully-featured offline music player with analytics, smart organization, mood playlists, gamification, and a polished Material 3 dark UI.

---

## 📁 Project Structure

```
smart_music_player/
├── lib/
│   ├── main.dart                    # App entry point, background audio init
│   ├── models/
│   │   ├── song.dart                # Song model + metadata
│   │   ├── playlist.dart            # Playlist model
│   │   └── user_stats.dart          # UserStats, ListeningHistory, Badge models
│   ├── database/
│   │   └── database_helper.dart     # SQLite (sqflite) — all CRUD operations
│   ├── services/
│   │   ├── audio_player_service.dart   # just_audio playback engine
│   │   └── music_scanner_service.dart  # Device scan + file picker import
│   ├── providers/
│   │   └── music_provider.dart      # Central ChangeNotifier state manager
│   ├── theme/
│   │   └── app_theme.dart           # Dark theme, color palette, gradients
│   ├── widgets/
│   │   └── common_widgets.dart      # SongTile, MiniPlayer, GradientIconButton
│   └── screens/
│       ├── splash_screen.dart       # Animated splash
│       ├── main_screen.dart         # Bottom nav + mini player shell
│       ├── home_screen.dart         # Library: search, sort, import
│       ├── now_playing_screen.dart  # Full player with seek, volume, sleep timer
│       ├── playlist_screen.dart     # Playlists + detail view
│       ├── favorites_screen.dart    # Favorited songs
│       ├── analytics_screen.dart    # Charts, top songs, badges, mood stats
│       └── settings_screen.dart    # Scan, organize, mood player, duplicates
├── android/
│   └── app/src/main/
│       └── AndroidManifest.xml     # Storage + foreground service permissions
├── ios/
│   └── Runner/Info.plist           # Background audio, music library access
└── pubspec.yaml                    # All dependencies
```

---

## 🗄️ Database Schema (SQLite via sqflite)

### `songs`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | Auto-increment |
| title | TEXT | Song title |
| artist | TEXT | Artist name |
| file_path | TEXT UNIQUE | Full path to file |
| duration | INTEGER | Seconds |
| album | TEXT | Album name |
| is_favorite | INTEGER | 0/1 boolean |
| date_added | TEXT | ISO 8601 |
| play_count | INTEGER | Total plays |
| mood_tag | TEXT | happy/sad/focus/chill/workout |
| artwork_path | TEXT | Optional local artwork |

### `playlists`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT | Playlist name |
| created_at | TEXT | ISO 8601 |
| description | TEXT | Optional |
| is_auto_generated | INTEGER | 0/1 |

### `playlist_songs`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| playlist_id | INTEGER FK | → playlists.id CASCADE |
| song_id | INTEGER FK | → songs.id CASCADE |
| position | INTEGER | Order in playlist |

### `listening_history`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| song_id | INTEGER FK | → songs.id CASCADE |
| played_at | TEXT | ISO 8601 |
| duration_played | INTEGER | Seconds actually listened |

### `user_stats`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| total_play_time | INTEGER | Total seconds |
| total_songs_played | INTEGER | Cumulative count |
| streak_days | INTEGER | Consecutive days |
| last_played_date | TEXT | ISO 8601 |

### `badges`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| badge_type | TEXT UNIQUE | BadgeType enum name |
| is_unlocked | INTEGER | 0/1 |
| unlocked_at | TEXT | ISO 8601 |

---

## 🚀 Setup Instructions

### 1. Install Flutter
```bash
flutter doctor
```

### 2. Clone / copy project files, then:
```bash
cd smart_music_player
flutter pub get
```

### 3. Run on device/emulator
```bash
flutter run
```

### 4. Build release APK
```bash
flutter build apk --release
```

---

## 📦 Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| sqflite | ^2.3.3 | Local SQLite database |
| just_audio | ^0.9.40 | Audio playback engine |
| just_audio_background | ^0.0.1-beta.13 | Background play + notification |
| audio_session | ^0.1.21 | Audio focus management |
| file_picker | ^8.0.7 | Manual file import |
| permission_handler | ^11.3.1 | Storage permissions |
| path_provider | ^2.1.3 | File system paths |
| provider | ^6.1.2 | State management |
| fl_chart | ^0.68.0 | Analytics bar charts |
| google_fonts | ^6.2.1 | Space Grotesk typography |
| palette_generator | ^0.3.3+3 | Dynamic theme from artwork |
| shared_preferences | ^2.2.3 | Settings persistence |
| intl | ^0.19.0 | Date formatting |

---

## ✨ Feature Checklist

### Core
- [x] Auto-scan device storage (MP3, WAV, M4A, AAC, FLAC)
- [x] Manual file picker import
- [x] Metadata extraction (title, artist, album, duration)
- [x] Play / Pause / Resume / Next / Previous
- [x] Shuffle and Repeat modes (off / all / one)
- [x] Background playback with notification controls
- [x] Seek bar with position tracking
- [x] Volume control slider
- [x] Search by title / artist / album
- [x] Sort: Recent / Title / Artist / Most Played
- [x] Favorites system (❤️)

### Playlists
- [x] Create / delete playlists
- [x] Add / remove songs from playlists
- [x] Auto-generate: Study Mix, Workout Mix, Chill Mix, Happy Vibes, Top 10

### Special Features
- [x] Smart organizer: Browse by artist, by album
- [x] Duplicate song detector
- [x] Listening analytics dashboard
- [x] Most played songs (Top 10)
- [x] Daily listening chart (7-day bar chart)
- [x] Streak tracking
- [x] Sleep timer (15 / 30 / 60 min) with fade-out
- [x] Mood tagging (happy, sad, focus, chill, workout)
- [x] Mood-based playlist player
- [x] Dynamic album art (gradient from song title hash)
- [x] Smooth animations (splash, now playing rotation, pulse)

### Gamification
- [x] 8 achievement badges
- [x] 7-Day Listener 🔥
- [x] 100 Songs Played 💯
- [x] Playlist Creator 🎵
- [x] Night Owl 🦉
- [x] Early Bird 🌅
- [x] Marathon Listener 🏆
- [x] Shuffle King 🎲
- [x] Favorites Collector ❤️

---

## 🎨 UI Screens

| Screen | Description |
|--------|-------------|
| Splash | Animated logo reveal with scale + fade |
| Home / Library | Song list with search, sort chips, import FAB |
| Now Playing | Rotating album art disc, gradient glow, seek bar, volume |
| Playlists | Smart + manual playlists with detail view |
| Favorites | Liked songs with play-all button |
| Analytics | Stats cards, bar chart, top songs, badges, mood chart |
| Settings | Scan, organize, mood player, duplicate finder |

---

## 🔧 Permissions Required

### Android
```xml
READ_MEDIA_AUDIO          <!-- Android 13+ -->
READ_EXTERNAL_STORAGE     <!-- Android 12 and below -->
FOREGROUND_SERVICE        <!-- Background playback -->
FOREGROUND_SERVICE_MEDIA_PLAYBACK
WAKE_LOCK
```

### iOS
```
NSAppleMusicUsageDescription
UIBackgroundModes: audio
```

---

## 💡 Important Notes for Defense

1. **Database**: SQLite with 6 tables, FK constraints with CASCADE delete, batch inserts for performance
2. **State**: Single `MusicProvider` ChangeNotifier — single source of truth
3. **Audio**: `just_audio` engine with `just_audio_background` for lock-screen controls
4. **Scanning**: Recursive directory traversal with depth limit, skips system dirs
5. **Analytics**: Real play-count tracking, listening history per session, streak logic
6. **Mood System**: Per-song mood tags drive both manual tagging and auto playlist generation
7. **Badges**: Checked on every stat update, stored in DB for persistence
8. **Sleep Timer**: Uses `dart:async Timer` with gradual volume fade over 30s
9. **Demo Mode**: Built-in demo songs with pre-seeded play counts and history for instant demo

---

## 🏗️ Architecture

```
UI (Screens/Widgets)
        ↕ Consumer/Provider
MusicProvider (ChangeNotifier)
        ↕
AudioPlayerService ←→ just_audio
        ↕
DatabaseHelper (sqflite)
        ↕
MusicScannerService ←→ file_picker / permission_handler
```
