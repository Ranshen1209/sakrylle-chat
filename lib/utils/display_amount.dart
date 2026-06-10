/// Format a display-only amount with the full-width yen sign (U+FFE5).
///
/// Per Sakrylle brand spec: display-only balances use full-width `￥`;
/// real CNY payment flows use half-width `¥` (U+00A5) — this helper is
/// for the display-only case.
String formatDisplayAmount(num amount, {int fractionDigits = 2}) {
  return '￥${amount.toStringAsFixed(fractionDigits)}';
}
