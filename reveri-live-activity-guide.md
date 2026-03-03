# Live Activity — Реализация для Reveri

## Что это
Карточка на Lock Screen с кнопками "Record" и "Write", висит пока юзер не запишет сон.

## Что нужно в Xcode

### 1. Создать Widget Extension
File → New → Target → Widget Extension (с галочкой "Include Live Activity")

### 2. Структура данных
```swift
struct DreamAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var status: String // "sleeping" / "wakeUp"
    }
    var startTime: Date
}
```

### 3. UI виджета (Lock Screen + Dynamic Island)
Используешь `ActivityConfiguration` + `DynamicIsland` в Widget Extension.
Кнопки Record/Write — это `Link(destination: URL("reveri://record"))`.

### 4. Deep Links
В основном приложении `.onOpenURL` — ловишь `reveri://record` и `reveri://write`, открываешь нужный экран.

### 5. Запуск
Юзер нажал "Иду спать" → `Activity.request(attributes:content:pushType:)`

### 6. Остановка
Юзер записал сон → `activity.end(dismissalPolicy: .immediate)`

### 7. Обход 8-часового лимита
Вариант A: `BGTaskScheduler` — обновляешь Activity каждые 7 часов (без сервера).
Вариант B: Push с сервера каждые 7 часов (надёжнее, нужен бэкенд).

## Порядок действий
1. Создать Widget Extension
2. Описать DreamAttributes
3. Сверстать UI карточки
4. Настроить URL Scheme (reveri://)
5. Добавить кнопку "Иду спать" в приложение
6. Добавить BGTask для обновления
