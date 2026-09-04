# BalanceMate

BalanceMate is a personal borrowing and lending tracker for the money shared
between people. Record when you lend, borrow, repay, or receive a repayment;
see at a glance what you owe and what others owe you; and keep a clear history
so no balance or due date is forgotten.

The Flutter application is being built for **Android** and **web**. iOS is not
currently in scope.

## Planned capabilities

- Keep a list of people and their current balances.
- Record loans, repayments, and adjustments with dates, notes, and currency.
- Clearly separate money **you owe** from money **owed to you**.
- Track optional due dates and surface overdue or upcoming balances.
- Preserve a full transaction history, including partially repaid loans.
- Start as an offline-first app, then add secure cloud backup and sync.

## Storage roadmap

The first release stores data on the device using `shared_preferences` (browser
local storage on web). A later release will use Firebase for authenticated cloud
storage and cross-device synchronisation. 
## Development

```bash
flutter pub get
flutter run -d chrome    # web
flutter run              # Android device or emulator
```

Run the automated checks with:

```bash
flutter analyze
flutter test
```
