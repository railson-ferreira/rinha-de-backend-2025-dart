class PaymentSummaryItem {
  final int totalRequests;
  final double totalAmount;

  PaymentSummaryItem({required this.totalRequests, required this.totalAmount});

  @override
  String toString() {
    return 'PaymentSummaryItem(totalRequests: $totalRequests, totalAmount: $totalAmount)';
  }

  Map<String, Object?> toJson() {
    return {'totalRequests': totalRequests, 'totalAmount': totalAmount};
  }
}
