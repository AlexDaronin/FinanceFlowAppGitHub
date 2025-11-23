# ✅ Finance App Prompt for Cursor

You are an experienced iOS app developer who explains things in grade 5 level English without technical jargon.  
Create a simple, step-by-step **REQUIREMENTS DOCUMENT** for an iOS app idea using Swift, SwiftUI, and Xcode.

The goal is for this document to:
1. Be easy to understand for someone who codes for fun.  
2. Use plain language, not technical jargon.  
3. Number each item clearly so I can refer to them later when asking you to implement in Cursor.

---

## 📱 App Idea

This app is a **simple, beautiful, and minimal personal finance manager** for normal people who want to understand and control their money easily.  
The main goal is to make managing finances **simple, clear, and helpful**, even for beginners.

---

## 🔵 Key Features and User Experience

### 1. Incomes, Expenses, and Transactions
- Users can add incomes and expenses.  
- Each entry becomes a transaction in a clean list.  
- Transactions can be filtered, sorted, and reviewed quickly.

### 2. Main Screen — Dashboard
- Shows **account balances** (multiple accounts, switchable, include/exclude in total balance).  
- Shows **planned vs. actual expenses**.  
- Quick stats: total income, total spent, remaining budget.  
- Buttons to quickly add income or expense.

### 3. Accounts
- Multiple accounts (cards, wallets, cash).  
- Each account shows its balance.  
- Users can switch between accounts easily.  
- Users can include or exclude each account from the total balance.

### 4. Planned Payments
- Store subscriptions, bills, and recurring payments.  
- Show next date and amount.

### 5. Credits / Loans
- Track loans or debts.  
- Show remaining balance and repayment progress.

### 6. AI Chat Accountant
- AI sees transactions and gives simple advice:  
  - How to save money  
  - How to manage payments  
  - How to improve spending habits  
- Stores AI chat history.

### 7. Settings
Users can manage:  
- Currency  
- App theme (light/dark/system)  
- Start day of financial month  
- App language  
- Add, edit, delete categories  
- Switch between accounts  
- Premium monthly subscription  
- Local backup of data

---

## 🔵 Design & Experience
- Minimalist, clean, soft, and friendly.  
- Smooth animations and modern UI.  
- Big, clear buttons, readable text, clean spacing.  
- Calm and pleasant experience from the first second.  
- Supports dark and light mode.  

---

## 🔵 Build Steps (Example)
- **B-001:** Create a new SwiftUI project named `"FinanceFlow1"`.  
- **B-002:** Build **Main Screen** with accounts, stats, planned vs actual expenses.  
- **B-003:** Add **Accounts list & switcher** connected to Accounts data.  
- **B-004:** Add **Transaction list** connected to Transactions data.  
- **B-005:** Add **Add Income / Expense buttons** and transaction creation logic.  
- **B-006:** Add **Transaction Details / Edit Screen**.  
- **B-007:** Add **Planned Payments Screen** connected to Planned Payments data.  
- **B-008:** Add **Credits / Loans Screen** connected to Credits data.  
- **B-009:** Add **Statistics Screen** with charts for income, expenses, and planned vs actual spending.  
- **B-010:** Add **AI Chat Screen** connected to AI Chat history.  
- **B-011:** Add **Settings Screen** (currency, theme, start of month, language, categories, account switcher, subscription).  
- **B-012:** Implement navigation and data passing between all screens.  
- **B-013:** Add error handling for empty inputs, invalid data, or failed AI responses.  
- **B-014:** Test dark and light modes.  
- **B-015:** Test on multiple iPhone sizes for layout correctness.  
- **B-016:** Add debug logs and comments for readability.

---

## 🔵 Data to Store
- Transactions (amount, type, date, category, account)  
- Planned Payments (name, amount, next date, account)  
- Accounts (balance, type, included in total)  
- Credits / Loans (remaining balance, account, due date)  
- AI Chat history  
- Categories  
- User settings (currency, theme, language, start day of month, subscription status)