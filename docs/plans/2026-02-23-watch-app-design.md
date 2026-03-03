# Apple Watch App — Design Document

## Summary

Watch-приложение для быстрой записи снов голосом. Аудио записывается на Watch, передаётся на iPhone для распознавания и пост-обработки. Данные синхронизируются через SwiftData + CloudKit.

## Scope (v1)

- Запись аудио на Watch (AVAudioRecorder)
- Выбор эмоции после записи (7 эмоций как в iPhone)
- Сохранение Dream в SwiftData (sync через CloudKit)
- Передача аудиофайла на iPhone через WatchConnectivity
- Complication для быстрого запуска с циферблата

## Out of Scope

- Распознавание речи на Watch (делается на iPhone)
- Просмотр журнала снов на Watch
- AI-интерпретация на Watch
- Текстовый ввод на Watch

## Architecture

### Sync Strategy

**SwiftData + CloudKit** — единая база данных:
- iPhone и Watch используют один и тот же `ModelContainer(for: Dream.self, DreamFolder.self)` с CloudKit
- Синхронизация автоматическая через iCloud
- Offline-first: данные сохраняются локально, синхронизируются при подключении

**WatchConnectivity** — передача аудиофайлов:
- `WCSession.transferFile()` — фоновая надёжная передача аудио Watch → iPhone
- iPhone получает файл, запускает SpeechRecognitionService, сохраняет транскрипт в Dream
- Fallback: если iPhone не доступен, аудио остаётся на Watch, передастся позже

### Data Flow

```
Watch: Record audio → Save Dream (text="", audioFilePath=local) → Pick emotion → Save
  ↓ WatchConnectivity.transferFile()
iPhone: Receive audio → Run speech recognition → Update Dream.text via CloudKit sync
  ↓ CloudKit
Watch: Dream.text appears (synced)
```

### Shared Code (Target Membership)

Файлы с membership в обоих таргетах (iPhone + Watch):
- `ReveriAI/Models/Dream.swift`
- `ReveriAI/Models/DreamEmotion.swift`
- `ReveriAI/Models/DreamFolder.swift`
- `ReveriAI/Extensions/Color+Hex.swift`

### New Files (Watch Target)

```
ReveriAIWatch/
├── ReveriAIWatchApp.swift       # Entry point + ModelContainer
├── RecordingView.swift          # Main screen: record button + waveform
├── EmotionPickerView.swift      # Emotion grid after recording
├── WatchAudioRecorder.swift     # AVAudioRecorder wrapper for watchOS
├── WatchConnectivityService.swift  # Send audio to iPhone
└── Assets.xcassets/             # Watch app icon, complication assets
```

### New Files (iPhone Target — additions)

```
ReveriAI/Services/WatchConnectivityService.swift  # Receive audio from Watch
```

## UI Screens

### Screen 1: Recording (main)
- Большая круглая кнопка записи (как в iPhone app)
- Аудио-волна во время записи (упрощённая версия AudioWaveformView)
- Таймер записи
- Кнопка стоп → переход к экрану 2

### Screen 2: Emotion Picker
- Сетка 7 эмоций (иконки + названия)
- Тап на эмоцию → сохранение Dream + начало передачи аудио на iPhone
- Кнопка "Пропустить" (сохранить без эмоции)

### Complication
- Graphic Circular: иконка приложения
- Тап → открывает RecordingView

## CloudKit Setup

1. Xcode → ReveriAI target → Signing & Capabilities → + iCloud → CloudKit
2. Создать CloudKit container: `iCloud.com.reveri.ReveriAI`
3. Добавить тот же container к Watch target
4. SwiftData автоматически использует CloudKit при наличии entitlement

## Key Constraints

- watchOS AVAudioRecorder: PCM 16-bit, 16kHz (совместимо с SpeechRecognition на iPhone)
- WatchConnectivity `transferFile()`: работает в фоне, очередь FIFO, надёжная доставка
- CloudKit sync latency: 1-15 секунд обычно
- Watch экран: ~198x242pt (48mm)
