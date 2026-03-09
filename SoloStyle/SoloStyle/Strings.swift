//
//  Strings.swift
//  SoloStyle
//
//  Localization manager — Russian (default) + English
//

import SwiftUI
import Combine

// MARK: - Language Manager

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    @AppStorage("appLanguage") var language: String = "ru" {
        didSet { objectWillChange.send() }
    }

    var isRussian: Bool { language == "ru" }
}

// MARK: - Localized strings accessor

enum L {
    private static var isRu: Bool { LanguageManager.shared.isRussian }

    // MARK: - Tabs
    static var tabCalendar: String { isRu ? "Записи" : "Calendar" }
    static var tabClients: String { isRu ? "Клиенты" : "Clients" }
    static var tabAI: String { "AI" }
    static var tabProfile: String { isRu ? "Профиль" : "Profile" }
    static var tabSettings: String { isRu ? "Ещё" : "Settings" }

    // MARK: - Common
    static var save: String { isRu ? "Сохранить" : "Save" }
    static var cancel: String { isRu ? "Отмена" : "Cancel" }
    static var delete: String { isRu ? "Удалить" : "Delete" }
    static var done: String { isRu ? "Готово" : "Done" }
    static var edit: String { isRu ? "Редактировать" : "Edit" }
    static var add: String { isRu ? "Добавить" : "Add" }
    static var back: String { isRu ? "Назад" : "Back" }
    static var close: String { isRu ? "Закрыть" : "Close" }
    static var search: String { isRu ? "Поиск" : "Search" }
    static var clear: String { isRu ? "Очистить" : "Clear" }
    static var actionCannotBeUndone: String { isRu ? "Это действие нельзя отменить." : "This action cannot be undone." }

    // MARK: - Settings
    static var settings: String { isRu ? "Настройки" : "Settings" }
    static var preferences: String { isRu ? "Настройки" : "Preferences" }
    static var notifications: String { isRu ? "Уведомления" : "Notifications" }
    static var appointmentReminders: String { isRu ? "Напоминания о записях" : "Appointment reminders" }
    static var calendarSync: String { isRu ? "Синхр. календаря" : "Calendar Sync" }
    static var syncWithIOSCalendar: String { isRu ? "Синхронизация с iOS Календарём" : "Sync with iOS Calendar" }
    static var language: String { isRu ? "Язык" : "Language" }
    static var data: String { isRu ? "Данные" : "Data" }
    static var exportData: String { isRu ? "Экспорт данных" : "Export Data" }
    static var support: String { isRu ? "Поддержка" : "Support" }
    static var helpCenter: String { isRu ? "Справка" : "Help Center" }
    static var contactUs: String { isRu ? "Связаться с нами" : "Contact Us" }
    static var rateApp: String { isRu ? "Оценить приложение" : "Rate App" }
    static var privacyPolicy: String { isRu ? "Политика конфиденциальности" : "Privacy Policy" }
    static var developer: String { isRu ? "Разработчик" : "Developer" }
    static var resetOnboarding: String { isRu ? "Сбросить знакомство" : "Reset Onboarding" }
    static var appFooter: String { isRu ? "Создано с любовью для мастеров" : "Made with love for solo professionals" }
    static var restartForLanguage: String { isRu ? "Перезапустите приложение для смены языка" : "Restart the app to apply language changes" }

    // MARK: - Settings — Help Center
    static var faqItems: [(String, String)] {
        isRu ? [
            ("Как добавить нового клиента?", "Перейдите на вкладку Клиенты и нажмите кнопку + чтобы добавить нового клиента."),
            ("Как создать запись?", "Откройте вкладку Календарь, выберите дату и нажмите + для создания новой записи."),
            ("Как добавить услугу?", "Перейдите в Профиль, прокрутите до раздела Услуги и нажмите + для добавления."),
            ("Как отметить запись выполненной?", "Нажмите на запись чтобы раскрыть её, затем нажмите «Готово»."),
        ] : [
            ("How do I add a new client?", "Go to the Clients tab and tap the + button to add a new client with their contact information."),
            ("How do I schedule an appointment?", "Navigate to the Calendar tab, select a date, and tap the + button to create a new appointment."),
            ("How do I add a service?", "Go to your Profile tab, scroll to Services section and tap + to add a new service with price and duration."),
            ("How do I mark an appointment as completed?", "Tap on the appointment to expand it, then tap 'Complete' to mark it as done."),
        ]
    }

    // MARK: - Settings — Contact Us
    static var needHelp: String { isRu ? "Нужна помощь?" : "Need Help?" }
    static var contactDescription: String { isRu ? "Мы всегда готовы помочь! Свяжитесь с нами удобным способом." : "We're here to help! Contact us through any of the following channels." }
    static var emailSupport: String { isRu ? "Написать на почту" : "Email Support" }
    static var visitWebsite: String { isRu ? "Открыть сайт" : "Visit Website" }

    // MARK: - Settings — Privacy Policy
    static var ppDataCollection: String { isRu ? "Сбор данных" : "Data Collection" }
    static var ppDataCollectionText: String { isRu ? "SoloStyle хранит все данные локально на вашем устройстве. Мы не собираем и не передаём персональную информацию на внешние серверы." : "SoloStyle stores all your data locally on your device. We do not collect or transmit any personal information to external servers." }
    static var ppLocalStorage: String { isRu ? "Локальное хранение" : "Local Storage" }
    static var ppLocalStorageText: String { isRu ? "Вся информация о клиентах, записях и настройках надёжно хранится на вашем устройстве с помощью SwiftData." : "All client information, appointments, and settings are stored securely on your device using Apple's SwiftData framework." }
    static var ppNoSharing: String { isRu ? "Без передачи третьим лицам" : "No Third-Party Sharing" }
    static var ppNoSharingText: String { isRu ? "Мы не передаём ваши данные третьим лицам. Ваша бизнес-информация остаётся приватной." : "We do not share your data with any third parties. Your business information remains private and under your control." }
    static var ppAnalytics: String { isRu ? "Аналитика" : "Analytics" }
    static var ppAnalyticsText: String { isRu ? "Мы можем собирать анонимную статистику использования для улучшения приложения. Эти данные не позволяют вас идентифицировать." : "We may collect anonymous usage analytics to improve the app experience. This data cannot be used to identify you." }
    static var ppContact: String { isRu ? "Контакты" : "Contact" }
    static var ppContactText: String { isRu ? "Если у вас есть вопросы о конфиденциальности, свяжитесь с нами: privacy@solostyle.app" : "If you have any questions about our privacy practices, please contact us at privacy@solostyle.app" }

    // MARK: - Clients
    static var clients: String { isRu ? "Клиенты" : "Clients" }
    static var searchByNamePhoneEmail: String { isRu ? "Поиск по имени, телефону или почте" : "Search by name, phone, or email" }
    static var filterAll: String { isRu ? "Все" : "All" }
    static var filterRecent: String { isRu ? "Недавние" : "Recent" }
    static var filterFrequent: String { isRu ? "Частые" : "Frequent" }
    static var filterNew: String { isRu ? "Новые" : "New" }
    static var total: String { isRu ? "Всего" : "Total" }
    static var showing: String { isRu ? "Показано" : "Showing" }
    static var noClientsYet: String { isRu ? "Пока нет клиентов" : "No Clients Yet" }
    static var addFirstClient: String { isRu ? "Добавьте первого клиента" : "Add your first client to get started" }
    static var addClient: String { isRu ? "Добавить клиента" : "Add Client" }
    static func noResultsFor(_ text: String) -> String { isRu ? "Ничего не найдено по «\(text)»" : "No results for \"\(text)\"" }
    static var tryDifferentSearch: String { isRu ? "Попробуйте другой запрос" : "Try a different search term" }
    static var sortBy: String { isRu ? "Сортировка" : "Sort By" }
    static var sortName: String { isRu ? "Имя" : "Name" }
    static var sortMostVisits: String { isRu ? "Больше визитов" : "Most Visits" }
    static var sortRecentlyActive: String { isRu ? "Последняя активность" : "Recently Active" }
    static var clientDetails: String { isRu ? "О клиенте" : "Client Details" }
    static var loyaltyStatus: String { isRu ? "Статус лояльности" : "Loyalty Status" }
    static var visits: String { isRu ? "визитов" : "visits" }
    static func toNextTier(_ n: Int) -> String { isRu ? "\(n) до след. уровня" : "\(n) to next tier" }
    static var maxTier: String { isRu ? "Макс. уровень!" : "Max tier!" }
    static var recentAppointments: String { isRu ? "Последние записи" : "Recent Appointments" }
    static var call: String { isRu ? "Звонок" : "Call" }
    static var message: String { isRu ? "SMS" : "Message" }
    static var email: String { isRu ? "Почта" : "Email" }
    static var editClient: String { isRu ? "Редактировать клиента" : "Edit Client" }
    static var newClient: String { isRu ? "Новый клиент" : "New Client" }
    static var name: String { isRu ? "Имя" : "Name" }
    static var phone: String { isRu ? "Телефон" : "Phone" }
    static var clientName: String { isRu ? "Имя клиента" : "Client name" }
    static var phonePlaceholder: String { isRu ? "+7 999 123 4567" : "+1 234 567 8900" }
    static var emailPlaceholder: String { isRu ? "email@example.com" : "email@example.com" }
    static var contactInfoTip: String { isRu ? "Контактные данные помогут связаться с клиентом для напоминаний" : "Adding contact info helps you reach clients for appointment reminders" }
    static var noContactInfo: String { isRu ? "Нет контактных данных" : "No contact info" }
    static var completed: String { isRu ? "Завершено" : "Completed" }
    static var lastVisit: String { isRu ? "Последний визит" : "Last Visit" }
    static var totalSpent: String { isRu ? "Всего потрачено" : "Total Spent" }
    static var never: String { isRu ? "Никогда" : "Never" }
    static var newLabel: String { isRu ? "Новый" : "New" }
    static var deleteClient: String { isRu ? "Удалить клиента?" : "Delete client?" }
    static var deleteClientMessage: String { isRu ? "Это действие нельзя отменить. Все данные клиента будут удалены." : "This action cannot be undone. All client data will be deleted." }

    // MARK: - Profile
    static var profile: String { isRu ? "Профиль" : "Profile" }
    static var yourName: String { isRu ? "Ваше имя" : "Your Name" }
    static var appointments: String { isRu ? "Записи" : "Appointments" }
    static var services: String { isRu ? "Услуги" : "Services" }
    static var earnings: String { isRu ? "Доход" : "Earnings" }
    static var thisMonth: String { isRu ? "Этот месяц" : "This Month" }
    static var thisYear: String { isRu ? "Этот год" : "This Year" }
    static var noServicesYet: String { isRu ? "Пока нет услуг" : "No services yet" }
    static var addService: String { isRu ? "Добавить услугу" : "Add Service" }
    static var addServicesClients: String { isRu ? "Добавьте услуги для клиентов" : "Add services that clients can book" }
    static var createProfile: String { isRu ? "Создать профиль" : "Create Profile" }
    static var editProfile: String { isRu ? "Редактировать профиль" : "Edit Profile" }
    static var changePhoto: String { isRu ? "Сменить фото" : "Change Photo" }
    static var takePhoto: String { isRu ? "Сделать фото" : "Take Photo" }
    static var chooseFromLibrary: String { isRu ? "Выбрать из галереи" : "Choose from Library" }
    static var choosePhoto: String { isRu ? "Выбрать фото" : "Choose Photo" }
    static var businessName: String { isRu ? "Название бизнеса" : "Business Name" }
    static var businessNameOptional: String { isRu ? "Название бизнеса (необязательно)" : "Business name (optional)" }
    static var yourNamePlaceholder: String { isRu ? "Ваше имя" : "Your name" }
    static var serviceName: String { isRu ? "Название услуги" : "Service Name" }
    static var serviceNamePlaceholder: String { isRu ? "например Стрижка" : "e.g. Haircut" }
    static var priceField: String { isRu ? "Цена (₽)" : "Price (USD)" }
    static var duration: String { isRu ? "Длительность" : "Duration" }
    static var preview: String { isRu ? "Предпросмотр" : "Preview" }
    static var deleteService: String { isRu ? "Удалить услугу" : "Delete Service" }
    static var deleteServiceQ: String { isRu ? "Удалить услугу?" : "Delete Service?" }
    static var editService: String { isRu ? "Редактировать услугу" : "Edit Service" }
    static var bookingLink: String { isRu ? "Ваша ссылка для записи" : "Your Booking Link" }
    static var shareWithClients: String { isRu ? "Поделитесь с клиентами для записи" : "Share with clients to receive bookings" }
    static var copied: String { isRu ? "Скопировано!" : "Copied!" }
    static var copyLink: String { isRu ? "Копировать" : "Copy Link" }
    static var share: String { isRu ? "Поделиться" : "Share" }
    static var memberSince: String { isRu ? "В SoloStyle с" : "Member since" }
    static var quickActions: String { isRu ? "Быстрые действия" : "Quick Actions" }
    static var viewAnalytics: String { isRu ? "Аналитика" : "Analytics" }
    static var shareProfile: String { isRu ? "Поделиться" : "Share" }
    static var exportLabel: String { isRu ? "Экспорт" : "Export" }
    static var workSchedule: String { isRu ? "График работы" : "Work Schedule" }
    static var myServices: String { isRu ? "Мои услуги" : "My Services" }
    static var avgPerMonth: String { isRu ? "Ср. в месяц" : "Avg/month" }
    static var totalEarnings: String { isRu ? "Всего заработано" : "Total Earned" }

    // MARK: - Profile — Work Schedule
    static var closed: String { isRu ? "Выходной" : "Closed" }
    static func dayName(_ day: String) -> String {
        guard isRu else { return day }
        switch day {
        case "Monday": return "Понедельник"
        case "Tuesday": return "Вторник"
        case "Wednesday": return "Среда"
        case "Thursday": return "Четверг"
        case "Friday": return "Пятница"
        case "Saturday": return "Суббота"
        case "Sunday": return "Воскресенье"
        default: return day
        }
    }

    // MARK: - Onboarding
    static var welcomeTitle: String { isRu ? "Добро пожаловать в SoloStyle" : "Welcome to SoloStyle" }
    static var welcomeSubtitle: String { isRu ? "Самый простой способ управлять записями" : "The simplest way to manage your appointments" }
    static var featureManage: String { isRu ? "Управление записями" : "Manage appointments" }
    static var featureReminders: String { isRu ? "Напоминания клиентам" : "Send reminders" }
    static var featureBooking: String { isRu ? "Ссылка для записи" : "Share booking link" }
    static var getStarted: String { isRu ? "Начать" : "Get Started" }
    static var continueText: String { isRu ? "Далее" : "Continue" }
    static var startUsingSoloStyle: String { isRu ? "Начать работу" : "Start Using SoloStyle" }
    static var createYourProfile: String { isRu ? "Создайте профиль" : "Create Your Profile" }
    static var tellAboutYourself: String { isRu ? "Расскажите о себе" : "Tell us about yourself" }
    static var namePlaceholder: String { isRu ? "Иван Иванов" : "John Doe" }
    static var businessPlaceholder: String { isRu ? "Студия Ивана" : "John's Studio" }
    static var profileTip: String { isRu ? "Отлично! Ваш профиль будет виден клиентам при записи." : "Great! Your profile will be visible to clients when they book appointments." }
    static var allSet: String { isRu ? "Всё готово!" : "You're All Set!" }
    static var allSetSubtitle: String { isRu ? "Начните управлять записями и поделитесь ссылкой для записи с клиентами." : "Start managing your appointments and share your booking link with clients." }
    static var quickStart: String { isRu ? "Быстрый старт" : "Quick Start" }
    static var tipAddServices: String { isRu ? "Добавить услуги" : "Add services" }
    static var tipAddClients: String { isRu ? "Добавить клиентов" : "Add clients" }
    static var tipShareLink: String { isRu ? "Поделиться ссылкой" : "Share link" }

    // MARK: - Calendar (non-Russian remnants)
    static var calendar: String { isRu ? "Календарь" : "Calendar" }

    // MARK: - Quick Actions (shortcuts)
    static var shortcutNewAppointment: String { isRu ? "Новая запись" : "New Appointment" }
    static var shortcutNewAppointmentSub: String { isRu ? "Создать новую запись" : "Schedule a new appointment" }
    static var shortcutAddClient: String { isRu ? "Добавить клиента" : "Add Client" }
    static var shortcutAddClientSub: String { isRu ? "Добавить нового клиента" : "Add a new client" }
    static var shortcutTodaySchedule: String { isRu ? "Расписание на сегодня" : "Today's Schedule" }
    static var shortcutTodayScheduleSub: String { isRu ? "Просмотр записей на сегодня" : "View today's appointments" }
    static var shortcutAnalytics: String { isRu ? "Аналитика" : "Analytics" }
    static var shortcutAnalyticsSub: String { isRu ? "Статистика бизнеса" : "View business insights" }

    // MARK: - Analytics
    static var analytics: String { isRu ? "Аналитика" : "Analytics" }
    static var revenue: String { isRu ? "Доход" : "Revenue" }
    static var avgTicket: String { isRu ? "Средний чек" : "Avg. Ticket" }
    static var revenueTrend: String { isRu ? "Динамика дохода" : "Revenue Trend" }
    static var noDataForPeriod: String { isRu ? "Нет данных за этот период" : "No data for this period" }
    static var topServices: String { isRu ? "Популярные услуги" : "Top Services" }
    static var noServicesData: String { isRu ? "Нет данных об услугах" : "No services data yet" }
    static var clientInsights: String { isRu ? "Статистика клиентов" : "Client Insights" }
    static var newClients: String { isRu ? "Новые" : "New Clients" }
    static var returning: String { isRu ? "Постоянные" : "Returning" }
    static var appointmentStatus: String { isRu ? "Статус записей" : "Appointment Status" }
    static func bookingsCount(_ n: Int) -> String { isRu ? "\(n) записей" : "\(n) bookings" }
    static var periodDay: String { isRu ? "День" : "Day" }
    static var periodWeek: String { isRu ? "Неделя" : "Week" }
    static var periodMonth: String { isRu ? "Месяц" : "Month" }
    static var periodYear: String { isRu ? "Год" : "Year" }
    static var whatToExport: String { isRu ? "Что экспортировать?" : "What to export?" }
    static var exportToCSV: String { isRu ? "Экспорт в CSV" : "Export to CSV" }
    static var exportClients: String { isRu ? "Клиенты" : "Clients" }
    static var exportAppointments: String { isRu ? "Записи" : "Appointments" }
    static var exportRevenue: String { isRu ? "Отчёт о доходах" : "Revenue Report" }
    static var exportClientsDesc: String { isRu ? "Экспорт данных клиентов, контактов и истории визитов" : "Export all client data including contact info and visit history" }
    static var exportAppointmentsDesc: String { isRu ? "Экспорт всех записей с датами, услугами и статусами" : "Export all appointments with dates, services, and status" }
    static var exportRevenueDesc: String { isRu ? "Экспорт помесячной разбивки доходов" : "Export monthly revenue breakdown" }
    static var currencyCode: String { isRu ? "RUB" : "USD" }

    // MARK: - Gallery
    static var portfolio: String { isRu ? "Портфолио" : "Portfolio" }
    static var noPhotosYet: String { isRu ? "Нет фотографий" : "No Photos Yet" }
    static var addPhotosHint: String { isRu ? "Добавьте фото до/после к завершённым записям для портфолио" : "Add before/after photos to your completed appointments to build your portfolio" }
    static var allClients: String { isRu ? "Все клиенты" : "All Clients" }
    static var beforeAfterBadge: String { isRu ? "Д/П" : "B/A" }
    static var client: String { isRu ? "Клиент" : "Client" }
    static var service: String { isRu ? "Услуга" : "Service" }
    static var date: String { isRu ? "Дата" : "Date" }
    static var price: String { isRu ? "Цена" : "Price" }
    static var sharePhoto: String { isRu ? "Поделиться фото" : "Share Photo" }
    static var workDetails: String { isRu ? "Детали работы" : "Work Details" }
    static var beforeLabel: String { isRu ? "ДО" : "BEFORE" }
    static var afterLabel: String { isRu ? "ПОСЛЕ" : "AFTER" }
    static var beforeSection: String { isRu ? "До" : "Before" }
    static var afterSection: String { isRu ? "После" : "After" }
    static var savePhotos: String { isRu ? "Сохранить фото" : "Save Photos" }
    static var addPhotos: String { isRu ? "Добавить фото" : "Add Photos" }
    static var tapToAddPhoto: String { isRu ? "Нажмите для добавления фото" : "Tap to add photo" }
    static func shareText(service: String, client: String) -> String {
        isRu ? "\(service) для \(client) — Портфолио SoloStyle" : "\(service) for \(client) - SoloStyle Portfolio"
    }

    // MARK: - Reminders
    static var sendReminder: String { isRu ? "Отправить напоминание" : "Send Reminder" }
    static var messageTemplate: String { isRu ? "Шаблон сообщения" : "Message Template" }
    static var custom: String { isRu ? "Своё" : "Custom" }
    static var messagePreview: String { isRu ? "Предпросмотр сообщения" : "Message Preview" }
    static var chars: String { isRu ? "симв." : "chars" }
    static var typeYourMessage: String { isRu ? "Введите сообщение..." : "Type your message..." }
    static var sms: String { "SMS" }
    static var whatsapp: String { "WhatsApp" }
    static var noPhoneNumber: String { isRu ? "Нет номера телефона" : "No phone number available" }
    static var copyMessage: String { isRu ? "Копировать сообщение" : "Copy Message" }
    static var reminders: String { isRu ? "Напоминания" : "Reminders" }
    static var noUpcomingAppointments: String { isRu ? "Нет предстоящих записей" : "No Upcoming Appointments" }
    static var scheduleToRemind: String { isRu ? "Создайте записи для отправки напоминаний" : "Schedule appointments to send reminders" }
    static var tomorrow: String { isRu ? "Завтра" : "Tomorrow" }
    static var needsReminder: String { isRu ? "Нужно напомнить" : "Needs Reminder" }
    static var allUpcoming: String { isRu ? "Все предстоящие" : "All Upcoming" }
    static var atTime: String { isRu ? "в" : "at" }
    static var sent: String { isRu ? "Отправлено" : "Sent" }
    static var sendAction: String { isRu ? "Отправить" : "Send" }
    static var templateDayBefore: String { isRu ? "За день" : "Day Before" }
    static var templateHourBefore: String { isRu ? "За час" : "Hour Before" }
    static var templateConfirmation: String { isRu ? "Подтверждение" : "Confirmation" }
    static var templateThankYou: String { isRu ? "Спасибо" : "Thank You" }
    static var templateMissYou: String { isRu ? "Скучаем" : "We Miss You" }
    static func reminderDayBefore(client: String, service: String, date: String, business: String) -> String {
        isRu ? "Здравствуйте, \(client)! Напоминаем о записи на \(service) завтра в \(date). Ждём вас в \(business)!"
            : "Hi \(client)! Just a reminder about your \(service) appointment tomorrow at \(date). See you at \(business)!"
    }
    static func reminderHourBefore(client: String, service: String) -> String {
        isRu ? "Здравствуйте, \(client)! Ваша запись на \(service) через 1 час. Ждём вас!"
            : "Hi \(client)! Your \(service) appointment is in 1 hour. We're looking forward to seeing you!"
    }
    static func reminderConfirmation(client: String, service: String, date: String) -> String {
        isRu ? "Здравствуйте, \(client)! Ваша запись на \(service) (\(date)) подтверждена. Ответьте ДА для подтверждения или позвоните для переноса."
            : "Hi \(client)! Your \(service) appointment on \(date) is confirmed. Reply YES to confirm or call us to reschedule."
    }
    static func reminderThankYou(client: String, service: String, business: String) -> String {
        isRu ? "Спасибо за визит в \(business), \(client)! Надеемся, вам понравилась услуга \(service). До встречи!"
            : "Thank you for visiting \(business), \(client)! We hope you loved your \(service). See you next time!"
    }
    static func reminderMissYou(client: String, service: String, business: String) -> String {
        isRu ? "Здравствуйте, \(client)! Мы скучаем по вам в \(business)! Давно не видели вас. Запишитесь на \(service) сегодня!"
            : "Hi \(client)! We miss you at \(business)! It's been a while since your last visit. Book your next \(service) today!"
    }
    static var upcomingAppointmentNotif: String { isRu ? "Предстоящая запись" : "Upcoming Appointment" }
    static func appointmentInOneHour(client: String, service: String) -> String {
        isRu ? "\(client) — \(service) через 1 час" : "\(client) — \(service) in 1 hour"
    }

    // MARK: - AI Assistant
    static var aiAssistant: String { isRu ? "AI Ассистент" : "AI Assistant" }
    static var findMaster: String { isRu ? "Найди мастера" : "Find a Master" }
    static var findMasterSubtitle: String { isRu ? "Опиши, что тебе нужно, и я подберу лучших мастеров поблизости" : "Describe what you need and I'll find the best masters nearby" }
    static var describeService: String { isRu ? "Опишите услугу..." : "Describe a service..." }
    static var locationActive: String { isRu ? "Геолокация активна" : "Location active" }
    static var locationDenied: String { isRu ? "Геолокация не разрешена" : "Location not allowed" }
    static var foundMasters: String { isRu ? "Найденные мастера" : "Found masters" }
    static var priceLabel: String { isRu ? "цена" : "price" }
    static var distanceLabel: String { isRu ? "до вас" : "distance" }
    static var experienceLabel: String { isRu ? "стаж" : "experience" }
    static func yearsExp(_ n: Int) -> String { isRu ? "\(n) лет" : "\(n) yrs" }
    static var ourSalon: String { isRu ? "нашем салоне" : "our salon" }

    // MARK: - Map
    static var mastersOnMap: String { isRu ? "Мастера на карте" : "Masters on map" }
    static var you: String { isRu ? "Вы" : "You" }
    static var showOnMap: String { isRu ? "На карте" : "On map" }

    // MARK: - Booking
    static var bookAppointment: String { isRu ? "Записаться" : "Book" }
    static var bookingTitle: String { isRu ? "Запись к мастеру" : "Book an Appointment" }
    static var selectDateTime: String { isRu ? "Дата и время" : "Date & Time" }
    static var yourPhone: String { isRu ? "Ваш телефон" : "Your phone" }
    static var bookingComment: String { isRu ? "Комментарий (необязательно)" : "Comment (optional)" }
    static var confirmBooking: String { isRu ? "Подтвердить запись" : "Confirm Booking" }
    static var bookingSuccess: String { isRu ? "Вы записаны!" : "You're booked!" }
    static var bookingSuccessMsg: String { isRu ? "Запись успешно создана. Мастер получит уведомление." : "Appointment created. The master will be notified." }
    static var great: String { isRu ? "Отлично" : "Great" }
    static var serviceLabel: String { isRu ? "Услуга" : "Service" }
    static var masterLabel: String { isRu ? "Мастер" : "Master" }
    static var ratingLabel: String { isRu ? "Рейтинг" : "Rating" }

    // MARK: - Voice CRM
    static var voiceCRM: String { isRu ? "Голосовая CRM" : "Voice CRM" }
    static var vcListening: String { isRu ? "Слушаю..." : "Listening..." }
    static var vcProcessing: String { isRu ? "Обрабатываю..." : "Processing..." }
    static var vcTapToSpeak: String { isRu ? "Нажмите и говорите" : "Tap and speak" }
    static var vcTapToStop: String { isRu ? "Нажмите для остановки" : "Tap to stop" }
    static var vcPreviewTitle: String { isRu ? "Проверьте данные" : "Review data" }
    static var vcSaveRecord: String { isRu ? "Сохранить запись" : "Save record" }
    static var vcRetry: String { isRu ? "Попробовать снова" : "Try again" }
    static var vcSaved: String { isRu ? "Запись создана!" : "Record created!" }
    static var vcSavedMsg: String { isRu ? "Клиент и запись успешно сохранены" : "Client and appointment saved successfully" }
    static var vcClientName: String { isRu ? "Имя клиента" : "Client name" }
    static var vcServiceName: String { isRu ? "Услуга" : "Service" }
    static var vcDate: String { isRu ? "Дата" : "Date" }
    static var vcTime: String { isRu ? "Время" : "Time" }
    static var vcPrice: String { isRu ? "Цена" : "Price" }
    static var vcPhone: String { isRu ? "Телефон" : "Phone" }
    static var vcNotes: String { isRu ? "Заметки" : "Notes" }
    static var vcMicDenied: String { isRu ? "Разрешите доступ к микрофону в Настройках" : "Allow microphone access in Settings" }
    static var vcNoData: String { isRu ? "Не удалось распознать данные" : "Could not parse data" }
    static var vcExample: String { isRu ? "Например: «Запиши Анну на стрижку завтра в 15:00»" : "E.g.: \"Book Anna for a haircut tomorrow at 3 PM\"" }

    // MARK: - AI Quick Actions
    static var qaHaircut: String { isRu ? "Стрижка" : "Haircut" }
    static var qaManicure: String { isRu ? "Маникюр" : "Manicure" }
    static var qaMassage: String { isRu ? "Массаж" : "Massage" }
    static var qaMakeup: String { isRu ? "Макияж" : "Makeup" }

    // MARK: - Auth & Roles
    static var continueWithTelegram: String { isRu ? "Войти через Telegram" : "Continue with Telegram" }
    static var welcome: String { isRu ? "Добро пожаловать" : "Welcome" }
    static var howDoYouWantToUseApp: String { isRu ? "Как вы хотите использовать приложение?" : "How do you want to use the app?" }
    static var roleMaster: String { isRu ? "Мастер" : "Professional" }
    static var roleMasterDescription: String { isRu ? "Управление клиентами, записями, аналитика" : "Manage clients, appointments, analytics" }
    static var roleClient: String { isRu ? "Клиент" : "Client" }
    static var roleClientDescription: String { isRu ? "Найти мастера, записаться с помощью AI" : "Find a professional, book with AI" }
    static var continueButton: String { isRu ? "Продолжить" : "Continue" }
    static var logout: String { isRu ? "Выйти" : "Log out" }
    static var authError: String { isRu ? "Ошибка авторизации" : "Authentication error" }
    static var openTelegram: String { isRu ? "Откройте Telegram" : "Open Telegram" }
    static var waitingForTelegram: String { isRu ? "Ожидание входа через Telegram..." : "Waiting for Telegram login..." }
    static var tabSearch: String { isRu ? "Поиск" : "Search" }
    static var tabMyBookings: String { isRu ? "Мои записи" : "My Bookings" }
    static var popularQueries: String { isRu ? "Популярные запросы" : "Popular queries" }
    static var queryHaircut: String { isRu ? "Стрижка" : "Haircut" }
    static var queryManicure: String { isRu ? "Маникюр" : "Manicure" }
    static var queryMassage: String { isRu ? "Массаж" : "Massage" }
    static var querySkincare: String { isRu ? "Уход за кожей" : "Skincare" }
    static var clientBookingsHint: String { isRu ? "Найдите мастера через AI-поиск и запишитесь" : "Find a professional via AI search and book" }
}
