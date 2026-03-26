import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

typedef MatchingSmsHandler =
    Future<void> Function(Map<String, dynamic> message);

class SmsService {
  SmsService({Telephony? telephony})
    : _telephony = telephony ?? Telephony.instance;

  // Keep lowercase because incoming text is normalized to lowercase.
  static const String targetSender = 'salama';
  static const String targetKeyword = 'salama';

  final Telephony _telephony;

  bool get _isAndroidSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> ensureSmsPermissions() async {
    if (!_isAndroidSupported) return false;

    try {
      final status = await Permission.sms.status;
      if (status.isGranted) return true;

      final requested = await Permission.sms.request();
      return requested.isGranted;
    } catch (e) {
      debugPrint('Impossible de verifier la permission SMS: $e');
      return false;
    }
  }

  bool isMatchingMessage({String? address, String? body}) {
    final normalizedAddress = (address ?? '').toLowerCase();
    final normalizedBody = (body ?? '').toLowerCase();

    final senderMatches =
        targetSender.isNotEmpty && normalizedAddress.contains(targetSender);
    final keywordMatches =
        targetKeyword.isNotEmpty && normalizedBody.contains(targetKeyword);

    return senderMatches || keywordMatches;
  }

  Future<List<Map<String, dynamic>>> getMatchingInboxMessages() async {
    if (!_isAndroidSupported) return [];

    final hasPermission = await ensureSmsPermissions();
    if (!hasPermission) {
      throw Exception('Permission SMS non accordee');
    }

    final inbox = await _telephony.getInboxSms(
      columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
    );

    return inbox
        .map(_toGenericMessage)
        .where(
          (message) => isMatchingMessage(
            address: message['address'] as String?,
            body: message['body'] as String?,
          ),
        )
        .toList(growable: false);
  }

  void startIncomingListener({required MatchingSmsHandler onMatchingMessage}) {
    if (!_isAndroidSupported) return;

    _telephony.listenIncomingSms(
      listenInBackground: false,
      onNewMessage: (SmsMessage sms) async {
        final message = _toGenericMessage(sms);
        if (!isMatchingMessage(
          address: message['address'] as String?,
          body: message['body'] as String?,
        )) {
          return;
        }

        await onMatchingMessage(message);
      },
    );
  }

  Map<String, dynamic> _toGenericMessage(SmsMessage sms) {
    final address = sms.address?.toString() ?? '';
    final body = sms.body?.toString() ?? '';

    String dateIso;
    final dynamic rawDate = sms.date;
    if (rawDate is DateTime) {
      dateIso = rawDate.toIso8601String();
    } else if (rawDate is int) {
      dateIso = DateTime.fromMillisecondsSinceEpoch(rawDate).toIso8601String();
    } else {
      dateIso = DateTime.now().toIso8601String();
    }

    return {'address': address, 'body': body, 'date': dateIso};
  }
}
