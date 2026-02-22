# 🤖 CURSOR HANDOFF — Инструкция для продолжения работы

> **ВАЖНО**: Этот документ создан Claude Code для передачи работы Cursor AI.
> После завершения работы — создай такой же документ для Claude Code!

---

## 📋 Текущий статус проекта

**Дата**: 2025-12-14 (обновлено)
**Передает**: Claude Code
**Принимает**: Cursor AI

### Что готово:
- ✅ Базовая структура iOS 26 приложения
- ✅ Design System с Liquid Glass
- ✅ Все основные экраны (Calendar, Clients, Profile, Settings)
- ✅ SwiftData модели (ЛОКАЛЬНОЕ хранение!)
- ✅ Анимации и haptic feedback
- ✅ Onboarding с confetti
- ✅ Исправлены FAB кнопки (подняты выше)
- ✅ Удален BreathingView
- ✅ Исправлен tab bar position
- ✅ Исправлена иконка Calendar (calendar.badge.clock)
- ✅ Удален blocking gesture в Calendar

### Что НЕ работает (известные баги):
1. **Settings** — кнопки могут не нажиматься, проверь `.contentShape(Rectangle())`
2. **Нужен русский язык** — добавить локализацию
3. **Сервер НЕ настроен** — данные только локально!

---

## 🛠️ Срочные исправления (сделай первым делом!)

### 1. Удалить BreathingView везде
Найди и удали использование `BreathingView` в:
- `GlassComponents.swift`
- `ProfileView.swift`
- Везде где используется

Замени на обычный статический View без анимации.

### 2. Опустить Tab Bar
В `GlassComponents.swift` найди `GlassTabBar` и добавь больший bottom padding:
```swift
.padding(.bottom, Design.Spacing.l) // было xs
```

### 3. Исправить MainTabView
В `MainTabView.swift` — tab bar должен быть в `safeAreaInset(edge: .bottom)`:
```swift
.safeAreaInset(edge: .bottom) {
    GlassTabBar(selectedTab: $selectedTab)
        .padding(.bottom, Design.Spacing.s)
}
```

### 4. Починить Settings scroll
В `SettingsView.swift`:
- Убедись что `ScrollView` имеет `.scrollBounceBehavior(.always)`
- Все `Button` должны иметь `.buttonStyle(.plain)` и `.contentShape(Rectangle())`

### 5. Починить Calendar
В `CalendarView.swift`:
- Проверь что все кнопки кликабельны
- FAB кнопка должна быть выше (`.padding(.bottom, Design.Spacing.xxl * 2)`)

---

## 📁 Структура файлов

```
SoloStyle/SoloStyle/SoloStyle/
├── SoloStyleApp.swift      # Entry point
├── DesignSystem.swift      # Design tokens, colors, typography
├── Models.swift            # SwiftData models
├── GlassComponents.swift   # UI components (GlassCard, GlassButton, etc.)
├── MainTabView.swift       # Tab navigation
├── CalendarView.swift      # Calendar screen
├── ClientsView.swift       # Clients list screen
├── ProfileView.swift       # Profile screen
├── SettingsView.swift      # Settings screen
└── OnboardingView.swift    # Onboarding flow
```

---

## 🎨 Design System

### Использование:
```swift
// Цвета
Design.Colors.backgroundPrimary
Design.Colors.accentPrimary
Design.Colors.textPrimary

// Типографика
Design.Typography.largeTitle
Design.Typography.headline
Design.Typography.body

// Отступы
Design.Spacing.xs  // 8
Design.Spacing.s   // 12
Design.Spacing.m   // 16
Design.Spacing.l   // 24
Design.Spacing.xl  // 32

// Анимации
Design.Animation.smooth
Design.Animation.bouncy

// Haptics
HapticManager.impact(.medium)
HapticManager.selection()
HapticManager.notification(.success)
```

---

## 📱 Данные

**ВАЖНО**: Сейчас данные хранятся ЛОКАЛЬНО на устройстве через SwiftData!

Сервер (77.110.115.239) НЕ настроен. Для будущего:
- Нужен backend API
- CloudKit для синхронизации между устройствами

---

## 🌍 Локализация

Нужно добавить:
- ✅ English (есть)
- ❌ Русский (добавить!)
- ✅ Spanish Mexico (есть)

Файл: `Localizable.xcstrings`

---

## 📋 TODO для Cursor

### Приоритет 1 — Баги:
- [ ] Удалить BreathingView (летающий круг)
- [ ] Опустить tab bar ниже
- [ ] Починить Settings (scroll + кнопки)
- [ ] Починить Calendar (клики)
- [ ] Поднять navigation title в Clients
- [ ] Увеличить иконку Calendar в tab bar
- [ ] Поднять FAB кнопку (+) в Calendar

### Приоритет 2 — Фичи:
- [ ] Добавить русский язык
- [ ] Реальный Liquid Glass эффект (iOS 26)
- [ ] EventKit интеграция
- [ ] iMessage напоминания

### Приоритет 3 — Улучшения:
- [ ] Темная тема
- [ ] Виджеты для Home Screen
- [ ] Apple Watch app
- [ ] Siri Shortcuts

---

## 🔧 Как запустить

1. Открой `SoloStyle.xcodeproj` в Xcode 26+
2. Выбери симулятор iPhone с iOS 26
3. Нажми Run (Cmd+R)

Для запуска на реальном устройстве:
1. Подключи iPhone кабелем
2. В Signing & Capabilities выбери свой Team
3. На iPhone: Настройки → VPN и управление устройством → Доверять

---

## 📝 Правила работы

1. **Используй существующий Design System** — не создавай новые цвета/шрифты
2. **Haptics везде** — каждая кнопка должна иметь HapticManager
3. **Анимации** — используй Design.Animation.smooth для переходов
4. **Тестируй на симуляторе** перед коммитом

---

## 🔄 После завершения работы

**ОБЯЗАТЕЛЬНО** создай файл `CLAUDE_HANDOFF.md` с:
1. Что ты сделал
2. Что осталось сделать
3. Известные баги
4. Инструкции для Claude Code

---

## 💬 Промпт для запуска Cursor

Скопируй и вставь в Cursor:

```
Привет! Ты продолжаешь работу над iOS приложением SoloStyle.

Прочитай файл CURSOR_HANDOFF.md — там полная инструкция от Claude Code.

Твои первые задачи:
1. Удали BreathingView — это анимированный круг который "летает" по экрану
2. Опусти tab bar ниже к краю экрана
3. Почини Settings — кнопки не кликаются, scroll не работает
4. Почини Calendar — ничего нельзя нажать
5. Добавь русский язык

После работы создай CLAUDE_HANDOFF.md для передачи обратно.
```

---

*Создано Claude Code — 2025-12-14*
