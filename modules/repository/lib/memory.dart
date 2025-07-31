import 'package:shared_kernel/payment_processor_enum.dart';
import 'package:shared_kernel/payment_processor_status.dart';
import 'package:shared_kernel/status_updater_leader.dart';

var currentStatusUpdaterLeader = StatusUpdaterLeader(
  leaderId: 'none',
  expiration: DateTime.fromMillisecondsSinceEpoch(0),
);

var paymentProcessorsStatuses = <PaymentProcessor, PaymentProcessorStatus>{};
