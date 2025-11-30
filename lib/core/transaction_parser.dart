import 'dart:developer';

enum TransactionType { income, expense }

class TransactionModel {
  final double amount;
  final TransactionType type;
  final DateTime timestamp;
  final String rawBody;
  final String? title;

  TransactionModel({
    required this.amount,
    required this.type,
    required this.timestamp,
    required this.rawBody,
    this.title,
  });

  @override
  String toString() {
    return 'TransactionModel(amount: $amount, type: $type, timestamp: $timestamp)';
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'type': type.index, // 0 for income, 1 for expense
      'timestamp': timestamp.millisecondsSinceEpoch,
      'rawBody': rawBody,
      'title': title,
    };
  }
}

class TransactionParser {
  static const List<String> _expenseKeywords = [
    "จ่าย",
    "ชำระ",
    "หัก",
    "โอนให้",
    "โอนไป",
    "ถอน",
    "Debit",
    "Paid",
    "To",
    "Purchase",
    "Payment",
  ];

  static const List<String> _incomeKeywords = [
    "รับโอน",
    "เงินเข้า",
    "ฝาก",
    "ได้รับ",
    "โอนมา",
    "Credit",
    "Received",
    "From",
    "Deposit",
  ];

  static const List<String> _ignoreKeywords = [
    "คงเหลือ",
    "Balance",
    "Avail",
    "Useable",
    "Total",
    "ยอดเงิน",
  ];

  static const List<String> _blockKeywords = [
    "OTP",
    "Ref:",
    "รหัส",
    "Reference",
    "Login",
    "Verification",
  ];

  static TransactionModel? parse(String? title, String? body) {
    if (body == null || body.isEmpty) return null;
    final String cleanBody = body.trim();

    // 1. Sanitization: Check for block keywords (OTP, etc.)
    for (final keyword in _blockKeywords) {
      if (cleanBody.contains(keyword)) {
        log("Ignored (Security/OTP): $cleanBody");
        return null;
      }
    }

    // 2. Extraction: Find the amount
    // Regex to find currency-like numbers.
    // Matches:
    // 1,234.56 (Comma and dot)
    // 1234.56 (Dot only)
    // 1,234 (Comma only)
    // 500.00
    // We avoid matching simple 4-digit years like 2024 unless they have decimals.
    // We also try to avoid time like 09:30.

    // Strategy:
    // 1. Look for explicit decimal patterns: \d+\.\d{2}
    // 2. Look for comma separated patterns: \d{1,3}(,\d{3})+(\.\d+)?

    final RegExp amountRegex = RegExp(
      r'(\d{1,3}(,\d{3})+(\.\d+)?)|(\d+\.\d{2})',
    );
    final Iterable<RegExpMatch> matches = amountRegex.allMatches(cleanBody);

    double? extractedAmount;

    // We need to be careful not to pick up the "Balance" amount.
    // Strategy: Look at the text *around* the match.
    for (final match in matches) {
      String amountStr = match.group(0)!;
      int start = match.start;

      // Check immediate context (before the number) for "Balance" keywords
      // We look at the substring before the match.
      String contextBefore = cleanBody.substring(0, start);

      bool isBalance = false;
      for (final ignore in _ignoreKeywords) {
        // Check if the ignore keyword appears shortly before the number (e.g. within 20 chars)
        int index = contextBefore.lastIndexOf(ignore);
        if (index != -1 && (start - index) < 20) {
          isBalance = true;
          break;
        }
      }

      if (!isBalance) {
        // Found a candidate
        try {
          extractedAmount = double.parse(amountStr.replaceAll(',', ''));
          // Filter out small integers that look like years (e.g. 2023, 2566) if they don't have decimals
          // But 2000 baht is valid.
          // Usually years are not formatted with commas "2,024".
          // So our regex \d{1,3}(,\d{3}) handles that safety.
          // But \d+\.\d{2} handles "2024.00".

          break; // Assume the first valid non-balance number is the transaction amount
        } catch (e) {
          continue;
        }
      }
    }

    if (extractedAmount == null) {
      log("Ignored (No valid amount found): $cleanBody");
      return null;
    }

    // 3. Classification (Scoring System)
    int expenseScore = 0;
    int incomeScore = 0;

    for (final keyword in _expenseKeywords) {
      if (cleanBody.contains(keyword)) expenseScore++;
    }

    for (final keyword in _incomeKeywords) {
      if (cleanBody.contains(keyword)) incomeScore++;
    }

    TransactionType type;
    if (expenseScore > incomeScore) {
      type = TransactionType.expense;
    } else if (incomeScore > expenseScore) {
      type = TransactionType.income;
    } else {
      // Default fallback or heuristic?
      // If ambiguous, maybe default to expense as it's more common for notifications?
      // Or return null?
      // Let's check for specific "To" vs "From" patterns if scores are equal.
      if (cleanBody.toLowerCase().contains(" to ")) {
        type = TransactionType.expense;
      } else if (cleanBody.toLowerCase().contains(" from ")) {
        type = TransactionType.income;
      } else {
        // Fallback
        type = TransactionType.expense;
      }
    }

    return TransactionModel(
      amount: extractedAmount,
      type: type,
      timestamp: DateTime.now(),
      rawBody: cleanBody,
      title: title,
    );
  }
}
