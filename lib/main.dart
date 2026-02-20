import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';

import 'database_helper.dart';
import 'sms_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  final smsService = SmsService();
  if (!smsService.isMatchingMessage(
    address: message.address,
    body: message.body,
  )) {
    return;
  }

  String dateIso;
  final dynamic rawDate = message.date;
  if (rawDate is DateTime) {
    dateIso = rawDate.toIso8601String();
  } else if (rawDate is int) {
    dateIso = DateTime.fromMillisecondsSinceEpoch(rawDate).toIso8601String();
  } else {
    dateIso = DateTime.now().toIso8601String();
  }

  await DatabaseHelper().saveMessage(
    address: message.address ?? '',
    body: message.body ?? '',
    date: dateIso,
  );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto SMS Airtel/NetMlay',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SmsAutoRecoveryScreen(),
    );
  }
}

class SmsAutoRecoveryScreen extends StatefulWidget {
  const SmsAutoRecoveryScreen({super.key});

  @override
  State<SmsAutoRecoveryScreen> createState() => _SmsAutoRecoveryScreenState();
}

class _SmsAutoRecoveryScreenState extends State<SmsAutoRecoveryScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SmsService _smsService = SmsService();

  List<Map<String, dynamic>> _savedMessages = [];
  bool _isInitializing = true;
  bool _isListening = false;
  String _statusMessage = 'Initialisation...';

  @override
  void initState() {
    super.initState();
    _initializeAutomaticRecovery();
  }

  Future<void> _initializeAutomaticRecovery() async {
    await _loadSavedMessages();
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _statusMessage = 'Vérification des permissions SMS...';
    });

    final hasPermission = await _smsService.ensureSmsPermissions();
    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _isInitializing = false;
        _isListening = false;
        _statusMessage =
            'Permission SMS refusée. Active-la pour la récupération automatique.';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Synchronisation des SMS existants...';
    });

    final matchingMessages = await _smsService.getMatchingInboxMessages();
    int processedCount = 0;

    for (final message in matchingMessages) {
      await _dbHelper.saveMessage(
        address: message['address']?.toString() ?? '',
        body: message['body']?.toString() ?? '',
        date: message['date']?.toString() ?? DateTime.now().toIso8601String(),
      );
      processedCount++;
    }

    await _loadSavedMessages();
    if (!mounted) return;

    _smsService.startIncomingListener(
      onMatchingMessage: _handleIncomingMatch,
      onBackgroundMessage: backgroundSmsHandler,
    );

    setState(() {
      _isInitializing = false;
      _isListening = true;
      _statusMessage =
          'Écoute active: Airtel OU NetMlay (automatique, foreground + background).';
    });

    if (processedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$processedCount SMS existants synchronisés.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleIncomingMatch(Map<String, dynamic> message) async {
    await _dbHelper.saveMessage(
      address: message['address']?.toString() ?? '',
      body: message['body']?.toString() ?? '',
      date: message['date']?.toString() ?? DateTime.now().toIso8601String(),
    );

    await _loadSavedMessages();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nouveau SMS Airtel/NetMlay sauvegardé automatiquement.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _loadSavedMessages() async {
    final messages = await _dbHelper.getMessages();
    if (!mounted) return;

    setState(() {
      _savedMessages = messages;
    });
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Date inconnue';

    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auto SMS Airtel/NetMlay')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      _isListening ? Icons.radio_button_checked : Icons.info,
                      color: _isListening ? Colors.green : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _isListening ? 'Écoute automatique active' : 'En attente',
                    ),
                    const Spacer(),
                    Text('Total: ${_savedMessages.length}'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isInitializing && _savedMessages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _savedMessages.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun SMS correspondant (Airtel OU NetMlay) sauvegardé.',
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    itemCount: _savedMessages.length,
                    itemBuilder: (context, index) {
                      final message = _savedMessages[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.sms),
                          title: Text(message['address'] ?? 'Inconnu'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                message['body'] ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(message['date']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
