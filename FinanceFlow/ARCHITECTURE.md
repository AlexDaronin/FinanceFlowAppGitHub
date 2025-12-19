# Clean Architecture + MVVM + Repository Pattern

## Структура

```
FinanceFlow/
├── Domain/                    # Бизнес-логика (независима от фреймворков)
│   ├── Entities/              # Чистые бизнес-модели
│   ├── UseCases/              # Бизнес-логика операций
│   └── Repositories/           # Протоколы репозиториев
│
├── Data/                       # Слой данных
│   └── Repositories/          # Реализации репозиториев (SwiftData)
│
└── Presentation/               # UI слой
    ├── ViewModels/            # ViewModels (MVVM)
    └── Adapters/              # Адаптеры для совместимости со старым кодом
```

## Принципы

### 1. Single Source of Truth
- **SwiftData** - единственное хранилище данных
- **Repositories** - единственная точка доступа к данным
- **ViewModels** подписываются на publishers из репозиториев
- **Нет дублирования** данных в памяти

### 2. Разделение ответственности

#### Domain Layer
- `TransactionEntity`, `AccountEntity` - чистые бизнес-модели
- `TransactionRepositoryProtocol`, `AccountRepositoryProtocol` - интерфейсы
- `CreateTransactionUseCase`, `UpdateTransactionUseCase` - бизнес-логика

#### Data Layer
- `TransactionRepository`, `AccountRepository` - реализация на SwiftData
- Маппинг между Domain entities и SwiftData models

#### Presentation Layer
- `TransactionViewModel`, `AccountViewModel` - состояние UI
- Используют UseCases для операций
- Подписываются на Repository publishers

### 3. Поток данных

```
View → ViewModel → UseCase → Repository → SwiftData
                ↓
            Publisher → ViewModel → View (обновление UI)
```

## Использование

### В FinanceFlowApp

```swift
// Инициализация новой архитектуры
let dependencies = Dependencies(modelContext: context)
let transactionViewModel = TransactionViewModel(...)
let accountViewModel = AccountViewModel(...)

// Адаптеры для совместимости со старым кодом
let transactionManager = TransactionManagerAdapter(viewModel: transactionViewModel)
let accountManager = AccountManagerAdapter(viewModel: accountViewModel)
```

### Создание транзакции

```swift
// В ViewModel автоматически вызывается UseCase
await viewModel.createTransaction(entity)

// UseCase:
// 1. Создает транзакцию через Repository
// 2. Обновляет балансы счетов
// 3. Repository публикует изменения
// 4. ViewModel получает обновление через publisher
// 5. View автоматически обновляется
```

## Миграция

### Текущее состояние
- Транзакции и счета используют новую архитектуру
- Старые Views работают через адаптеры
- Подписки, кредиты, долги пока используют старые менеджеры

### Следующие шаги
1. Мигрировать SubscriptionManager на новую архитектуру
2. Мигрировать CreditManager на новую архитектуру
3. Мигрировать DebtManager на новую архитектуру
4. Удалить старые менеджеры после полной миграции

## Преимущества

1. **Нет дублирования данных** - Single Source of Truth
2. **Тестируемость** - Domain слой независим от SwiftData
3. **Масштабируемость** - легко добавить пагинацию, кэширование
4. **Поддерживаемость** - четкое разделение ответственности
5. **Производительность** - данные загружаются по требованию


