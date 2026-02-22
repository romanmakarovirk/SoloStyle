# 🎯 Промпт для Claude Code — Исправление ошибок в SoloStyle

## Контекст проекта

Ты работаешь над iOS приложением **SoloStyle** для фрилансеров (iOS 26, SwiftUI, SwiftData).

**Структура проекта:**
- `SoloStyle/SoloStyle/SoloStyle/` — основной код
- `DesignSystem.swift` — система дизайна с Liquid Glass эффектами
- `Localizable.xcstrings` — файл локализации (EN + RU)
- Все остальные файлы работают корректно

---

## 🐛 Проблемы, которые нужно исправить

### 1. DesignSystem.swift — Ошибки компиляции

**Ошибки:**
- `Type 'any View' cannot conform to 'View'` (2 раза)
- `Type 'any View' cannot conform to 'ShapeStyle'`
- `Member 'fill' cannot be used on value of type 'any Shape'`

**Проблемный код:**
Функция `glassEffect()` в `DesignSystem.swift` пытается использовать `any Shape` неправильно.

**Текущая реализация (НЕ РАБОТАЕТ):**
```swift
func glassEffect(_ configuration: GlassEffectConfiguration = .regular, in shape: (any Shape)? = nil) -> some View {
    let material = configuration.style.material
    let defaultShape = RoundedRectangle(cornerRadius: Design.Radius.l)
    
    var view: AnyView
    
    if let tint = configuration.tint {
        if let customShape = shape {
            view = AnyView(
                self.background(material)
                    .clipShape(customShape)
                    .overlay(
                        defaultShape
                            .fill(tint)
                            .blendMode(.overlay)
                            .clipShape(customShape)
                    )
            )
        } else {
            // ...
        }
    }
    // ...
}
```

**Что нужно:**
- Исправить использование `any Shape` — нельзя вызывать `.fill()` на `any Shape`
- Использовать generic подход или конкретные типы
- Функция должна работать с любыми формами (RoundedRectangle, Circle, Capsule и т.д.)

**Подсказка:** Используй `@ViewBuilder` и generic constraints, или обрабатывай конкретные типы форм отдельно.

---

### 2. Localizable.xcstrings — Конфликты ключей локализации

**Ошибки:**
- `This string key would generate the same symbol as "Business name (optional)". Please change...`
- `This string key would generate the same symbol as "Delete Service?". Please change...`
- `This string key would generate the same symbol as "Your name". Please change...`

**Проблема:**
Xcode генерирует символы из ключей локализации, и некоторые ключи создают одинаковые имена символов, что вызывает конфликты.

**Текущие конфликтующие ключи:**
- `"Your Name field"` и `"Your name placeholder"` — могут конфликтовать
- `"Business Name optional field"` и `"Business name optional placeholder"` — могут конфликтовать
- `"Delete Service button"` и `"Delete Service alert"` — могут конфликтовать

**Что нужно:**
1. Переименовать ключи так, чтобы они генерировали уникальные символы
2. Обновить все использования этих ключей в коде (используется `String(localized:defaultValue:)`)

**Стратегия:**
- Используй более уникальные имена: `"fieldYourName"`, `"placeholderYourName"` вместо `"Your Name field"`, `"Your name placeholder"`
- Или используй префиксы: `"form.yourName"`, `"form.yourNamePlaceholder"`
- Главное — чтобы символы были уникальными (разный регистр первой буквы, разные слова)

**Файлы, где используются ключи:**
- `ProfileView.swift` — строки 106, 624, 627, 922, 944
- `OnboardingView.swift` — строки 175, 178

---

## ✅ Что уже сделано

- ✅ Базовая структура приложения готова
- ✅ Все экраны работают
- ✅ Локализация добавлена (EN + RU)
- ✅ Liquid Glass эффект частично реализован

---

## 🎯 Задача

**Исправь обе проблемы:**

1. **DesignSystem.swift** — перепиши `glassEffect()` так, чтобы она правильно работала с `any Shape` и не вызывала ошибок компиляции

2. **Localizable.xcstrings + код** — переименуй конфликтующие ключи локализации и обнови все их использования в коде

---

## 📋 Шаги выполнения

1. Прочитай `DesignSystem.swift` и найди функцию `glassEffect()`
2. Исправь использование `any Shape` — используй generic или конкретные типы
3. Прочитай `Localizable.xcstrings` и найди конфликтующие ключи
4. Переименуй ключи на более уникальные (например, `"fieldYourName"` вместо `"Your Name field"`)
5. Найди все использования этих ключей в коде (grep по `String(localized:`)
6. Обнови все использования на новые ключи
7. Проверь, что нет ошибок компиляции (`read_lints`)

---

## 🔍 Как проверить

После исправлений:
```bash
# Проверить JSON локализации
python3 -m json.tool SoloStyle/SoloStyle/Localizable.xcstrings

# Проверить ошибки линтера
# Используй read_lints tool
```

---

## 💡 Подсказки

**Для DesignSystem.swift:**
- Можно использовать `@ViewBuilder` с generic constraint
- Или обрабатывать конкретные типы форм (RoundedRectangle, Circle, Capsule) отдельно
- Или использовать type erasure правильно

**Для локализации:**
- Ключи должны быть уникальными на уровне символов Swift
- `"YourName"` и `"yourName"` — разные символы
- `"fieldYourName"` и `"placeholderYourName"` — разные символы
- Избегай пробелов и специальных символов в ключах (используй camelCase)

---

## 📝 Формат ответа

После исправлений:
1. Объясни, что было исправлено
2. Покажи ключевые изменения
3. Убедись, что нет ошибок компиляции

---

**ВАЖНО:** Данные хранятся ЛОКАЛЬНО (SwiftData). Сервер не настроен!




