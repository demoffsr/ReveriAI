---
name: localize-language
description: "Локализация на язык {название языка}. Добавляет новый язык в Xcode String Catalogs проекта ReveriAI. Использовать когда пользователь хочет добавить локализацию на новый язык."
argument-hint: "[название языка, например: French / Французский / de / ja]"
---

# Локализация на язык $ARGUMENTS

## Обзор задачи

Добавить переводы на язык **$ARGUMENTS** во все String Catalogs проекта ReveriAI:
- `ReveriAI/Localizable.xcstrings` — основное приложение
- `RecordingActivityWidget/Localizable.xcstrings` — виджет Live Activity

## Шаг 0 — Определить языковой код

Определи ISO 639-1 код языка из аргумента `$ARGUMENTS`. Примеры:
- French / Французский → `fr`
- German / Немецкий → `de`
- Spanish / Испанский → `es`
- Japanese / Японский → `ja`
- Chinese / Китайский → `zh-Hans`
- Korean / Корейский → `ko`
- Portuguese / Португальский → `pt-BR`
- Arabic / Арабский → `ar`
- Turkish / Турецкий → `tr`
- Italian / Итальянский → `it`

Если аргумент уже является кодом (например `de`, `ja`), использовать его напрямую.

## Шаг 1 — Проверить knownRegions в project.pbxproj

Прочитай `ReveriAI.xcodeproj/project.pbxproj`, найди все блоки `knownRegions = (...)`.

Если код языка **отсутствует** — добавь его в каждый блок `knownRegions`. Пример:
```
knownRegions = (en, ru, fr, Base,);
```

**ВАЖНО:** В pbxproj обычно 2 блока `knownRegions` (для project и root). Обнови ОБА.

## Шаг 2 — Добавить переводы в основной каталог

Прочитай файл `ReveriAI/Localizable.xcstrings`. Для КАЖДОГО ключа, у которого есть `"localizations"`, добавь блок с новым языком.

### Формат записи для обычных ключей

```json
"LANG_CODE" : {
  "stringUnit" : {
    "state" : "translated",
    "value" : "Переведённый текст"
  }
}
```

### Формат для плюрализации (`%lld Dreams`)

Ключ `"%lld Dreams"` требует plural variations. Правила плюрализации зависят от языка:

| Язык | Plural категории |
|------|-----------------|
| en | one, other |
| ru | one, few, many, other |
| fr, it, pt | one, other |
| de, nl, sv | one, other |
| ja, ko, zh | other (только) |
| ar | zero, one, two, few, many, other |
| pl, uk | one, few, many, other |
| cs, sk | one, few, many, other |
| tr | one, other |

Формат:
```json
"LANG_CODE" : {
  "variations" : {
    "plural" : {
      "one" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "%lld сон"
        }
      },
      "other" : {
        "stringUnit" : {
          "state" : "translated",
          "value" : "%lld снов"
        }
      }
    }
  }
}
```

### Полный список ключей для перевода (основное приложение)

Ниже — все ключи с английским (en) и русским (ru) значениями для контекста. Переводи **с английского** на целевой язык, используя русский как пример тона и стиля.

#### UI — Детали сна
| Ключ | en | ru |
|------|----|----|
| `detail.addTextForInterpretation` | Add a text description of your dream for interpretation | Добавьте текстовое описание сна для интерпретации |
| `detail.curiousMeaning` | Curious what it means? | Хотите узнать значение? |
| `detail.discoverSymbols` | Discover the symbols\nand emotions hidden within | Раскройте символы\nи эмоции, скрытые внутри |
| `detail.failedToGenerateImage` | Failed to generate image | Не удалось создать изображение |
| `detail.generate` | Generate | Сгенерировать |
| `detail.interpretingDream` | Interpreting dream... | Интерпретация сна... |
| `detail.navTitle` | Dream | Сон |
| `detail.original` | Original | Оригинал |
| `detail.preparingQuestions` | Preparing questions... | Подготовка вопросов... |
| `detail.processing` | Processing recording... | Обработка записи... |
| `detail.questionsSubtitle` | Answer the questions to create a more detailed visualization of your dream | Ответьте на вопросы, чтобы создать более детальную визуализацию вашего сна |
| `detail.skip` | Skip | Пропустить |
| `detail.tab.dream` | Dream | Сон |
| `detail.tab.meaning` | Meaning | Значение |
| `detail.tryAgain` | Try again | Повторить |
| `detail.visualizeDream` | Visualize Your Dream | Визуализация сна |
| `detail.whisper` | Whisper | Whisper |
| `detail.yourAnswer` | Your answer... | Ваш ответ... |

#### UI — Карточка сна
| Ключ | en | ru |
|------|----|----|
| `dreamCard.addToFolder` | Add to Folder | В папку |
| `dreamCard.cancel` | Cancel | Отмена |
| `dreamCard.delete` | Delete | Удалить |
| `dreamCard.deleteAction` | Delete | Удалить |
| `dreamCard.deleteConfirmation` | Delete dream? | Удалить сон? |
| `dreamCard.processing` | Processing recording... | Обработка записи... |
| `dreamCard.rename` | Rename | Переименовать |
| `dreamCard.share` | Share | Поделиться |

#### UI — Эмоции
| Ключ | en | ru |
|------|----|----|
| `emotion.angry` | Angry | Злой |
| `emotion.anxious` | Anxious | Тревожный |
| `emotion.calm` | Calm | Спокойный |
| `emotion.confused` | Confused | Озадаченный |
| `emotion.inLove` | In Love | Влюблённый |
| `emotion.joyful` | Joyful | Радостный |
| `emotion.scared` | Scared | Испуганный |

#### UI — Папки
| Ключ | en | ru |
|------|----|----|
| `folder.addDreamsHint` | Add dreams | Добавить сны |
| `folder.addDreamsTitle` | Add Dreams | Добавить сны |
| `folder.addDreamsToFolder` | Add dreams to this folder | Добавьте сны в эту папку |
| `folder.addToFolder` | Add to Folder | В папку |
| `folder.cancel` | Cancel | Отмена |
| `folder.create` | Create | Создать |
| `folder.createFirst` | Create a folder first | Сначала создайте папку |
| `folder.delete` | Delete | Удалить |
| `folder.done` | Done | Готово |
| `folder.folderName` | Folder name | Название папки |
| `folder.newFolder` | New Folder | Новая папка |
| `folder.noDreams` | No dreams | Нет снов |
| `folder.noFolders` | No folders | Нет папок |
| `folder.rename` | Rename | Переименовать |

#### UI — Журнал
| Ключ | en | ru |
|------|----|----|
| `journal.dreams` | Dreams | Сны |
| `journal.folders` | Folders | Папки |
| `journal.myDreams` | My Dreams | Мои сны |
| `journal.noFoldersYet` | No folders yet | Папок пока нет |
| `journal.search` | Search | Поиск |
| `journal.searchPlaceholder` | Search for dream or folder... | Поиск сна или папки... |
| `journal.sweetDreams` | Sweet dreams ahead | Впереди сладкие сны |
| `journal.tapNewFolder` | Tap "New Folder" to create one | Нажмите «Новая папка», чтобы создать |
| `journal.tapRecord` | Tap Record after you wake up\nto start your journal | Нажмите Запись после пробуждения,\nчтобы начать свой журнал |

#### UI — Поиск
| Ключ | en | ru |
|------|----|----|
| `search.dreams` | Dreams | Сны |
| `search.folders` | Folders | Папки |
| `search.noResults` | No results | Нет результатов |

#### UI — Запись
| Ключ | en | ru |
|------|----|----|
| `record.addDreamDescription` | Add dream description... | Добавьте описание сна... |
| `record.describe` | Describe | Опишите |
| `record.done` | Done | Готово |
| `record.dream` | dream | сон |
| `record.dreamSaved` | Dream saved | Сон сохранён |
| `record.enterDream` | Enter your dream... | Опишите ваш сон... |
| `record.howDidItFeel` | How did it feel? | Как это ощущалось? |
| `record.liveCaptions` | Live Captions will appear here | Здесь появится текст |
| `record.saveDream` | Save Dream | Сохранить |
| `record.startRecording` | Start Recording | Начать запись |
| `record.textMode` | Text Mode | Текст |
| `record.voiceMode` | Voice Mode | Голос |
| `record.your` | your  | ваш  |

#### UI — Табы и бар
| Ключ | en | ru |
|------|----|----|
| `tab.journal` | Journal | Журнал |
| `tab.record` | Record | Запись |
| `tabBar.cancel` | Cancel | Отмена |
| `tabBar.cannotBeUndone` | This action cannot be undone | Это действие нельзя отменить |
| `tabBar.delete` | Delete | Удалить |
| `tabBar.deleteRecording` | Delete recording? | Удалить запись? |
| `tabBar.generateAgain` | Generate Again | Создать заново |
| `tabBar.generateImage` | Generate Image | Создать изображение |
| `tabBar.interpretDream` | Interpret Dream | Интерпретировать сон |
| `tabBar.play` | Play | Воспроизвести |
| `tabBar.resume` | Resume | Продолжить |
| `tabBar.saveFeelings` | Save feelings | Сохранить эмоции |
| `tabBar.stop` | Stop | Стоп |

#### UI — Временные фильтры
| Ключ | en | ru |
|------|----|----|
| `timeRange.allTime` | All time | За всё время |
| `timeRange.thisMonth` | This month | В этом месяце |
| `timeRange.thisWeek` | This week | На этой неделе |
| `timeRange.today` | Today | Сегодня |

#### UI — Профиль
| Ключ | en | ru |
|------|----|----|
| `profile.about` | About | О приложении |
| `profile.addName` | Add name | Добавить имя |
| `profile.appearance` | Appearance | Оформление |
| `profile.auto` | Auto | Авто |
| `profile.cancel` | Cancel | Отмена |
| `profile.choosePhoto` | Choose Photo | Выбрать фото |
| `profile.clearCache` | Clear Cache | Очистить кэш |
| `profile.contactUs` | Contact Us | Связаться с нами |
| `profile.data` | Data | Данные |
| `profile.day` | Day | День |
| `profile.days` | Days | Дни |
| `profile.dreamReminder` | Dream Reminder | Напоминание о снах |
| `profile.enableReminder` | Enable Reminder | Включить напоминание |
| `profile.headerPhoto` | Header Photo | Фото шапки |
| `profile.language` | Language | Язык |
| `profile.night` | Night | Ночь |
| `profile.pinchToZoom` | Pinch to zoom, drag to reposition | Сведите пальцы для масштаба, перетащите для позиции |
| `profile.positionAndScale` | Position & Scale | Положение и масштаб |
| `profile.privacyPolicy` | Privacy Policy | Политика конфиденциальности |
| `profile.rateApp` | Rate the App | Оценить приложение |
| `profile.recordBackground` | Record Background | Фон записи |
| `profile.resetToDefault` | Reset to Default | Сбросить |
| `profile.save` | Save | Сохранить |
| `profile.sendTestNotification` | Send Test Notification | Отправить тестовое уведомление |
| `profile.speechRecognition` | Speech Recognition | Распознавание речи |
| `profile.support` | Support | Поддержка |
| `profile.termsOfUse` | Terms of Use | Условия использования |
| `profile.theme` | Theme | Тема |
| `profile.time` | Time | Время |
| `profile.title` | Profile | Профиль |
| `profile.version` | Version | Версия |
| `profile.yourName` | Your name | Ваше имя |

#### Intents
| Ключ | en | ru |
|------|----|----|
| `Start Recording` | Start Recording | Начать запись |
| `Stop Recording` | Stop Recording | Остановить запись |

#### Плюрализация
| Ключ | en (one/other) | ru (one/few/many/other) |
|------|---------------|------------------------|
| `%lld Dreams` | %lld Dream / %lld Dreams | %lld сон / %lld сна / %lld снов / %lld снов |

#### Юридические тексты
| Ключ | Описание |
|------|----------|
| `legal.privacyPolicyText` | Полный текст Privacy Policy — переведи целиком, сохраняя структуру пунктов и email |
| `legal.termsOfUseText` | Полный текст Terms of Use — переведи целиком, сохраняя структуру пунктов и email |

Для юридических текстов — прочитай текущие английские значения из `ReveriAI/Localizable.xcstrings` и переведи полностью.

## Шаг 3 — Добавить переводы в виджет

Прочитай `RecordingActivityWidget/Localizable.xcstrings` и добавь переводы для 7 ключей:

| Ключ | en | ru |
|------|----|----|
| `widget.didYouSleepWell` | Did you sleep well? | Хорошо ли спалось? |
| `widget.tellUsAboutIt` | Tell us about it | Расскажите об этом |
| `widget.record` | Record | Записать |
| `widget.recordYourDream` | Record your dream | Запишите свой сон |
| `widget.dream` | Dream | Сон |
| `Start Recording` | Start Recording | Начать запись |
| `Stop Recording` | Stop Recording | Остановить запись |

## Шаг 4 — Собрать и проверить

```bash
xcodebuild -scheme ReveriAI -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "(BUILD|error:)" | head -10
```

Если BUILD SUCCEEDED:
1. Проверь наличие `LANG_CODE.lproj` в бандле:
```bash
ls DerivedData/.../ReveriAI.app/LANG_CODE.lproj/
```
2. Проверь содержимое переводов:
```bash
plutil -p DerivedData/.../ReveriAI.app/LANG_CODE.lproj/Localizable.strings | head -20
```
3. Проверь виджет:
```bash
plutil -p DerivedData/.../PlugIns/RecordingActivityWidgetExtension.appex/LANG_CODE.lproj/Localizable.strings
```

DerivedData путь: `/Users/ddemidov/Library/Developer/Xcode/DerivedData/ReveriAI-evskxsdhatzlctdtdnvqjqtweczr/Build/Products/Release-iphonesimulator/`

## Важные правила

1. **НЕ трогай Swift-код** — все `String(localized:)` уже на месте, нужно только добавить переводы в `.xcstrings`
2. **Сохраняй `\n` в значениях** — многострочные строки (discoverSymbols, tapRecord) должны сохранять переносы
3. **`detail.whisper`** — оставь "Whisper" (это бренд/название)
4. **`record.your`** — обрати внимание на пробел в конце ("your "), он конкатенируется с "dream"
5. **JSON валидность** — убедись что xcstrings остаётся валидным JSON после правок
6. **Юридические тексты** — email `demidovdmitry07@gmail.com` НЕ переводится, даты "February 2026" переводятся на целевой язык
7. **Параллельная работа** — запускай subagent-ы для перевода основного каталога и виджета параллельно, но pbxproj правь в main контексте
