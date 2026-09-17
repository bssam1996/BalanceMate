/// Shared limits keep user supplied data readable and safely bounded in both
/// local storage and Cloud Firestore.
abstract final class InputLimits {
  static const name = 60;
  static const billTitle = 80;
  static const itemName = 80;
  static const phone = 30;
  static const email = 254;
  static const note = 500;
  static const maxAmountMinor = 99999999999; // 999,999,999.99
  static const maxPercent = 100;
  static const maxBillParticipants = 50;
  static const maxBillItems = 100;
  static const maxBillImportCharacters = 32768;
  static const maxBillItemQuantity = 9999;
}
