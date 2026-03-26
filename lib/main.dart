import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'database_helper.dart';
import 'sms_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto SMS',
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

class _SmsAutoRecoveryScreenState extends State<SmsAutoRecoveryScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _backgroundSmsChannel = MethodChannel(
    'get_smm/background_sms',
  );

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final SmsService _smsService = SmsService();

  List<Map<String, dynamic>> _savedMessages = [];
  bool _isInitializing = true;
  bool _isListening = false;
  String _statusMessage = 'Initialisation...';
  String _messagesSnapshot = '0';
  Timer? _autoRefreshTimer;
  int _recoveredFromNativeQueue = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAutomaticRecovery();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshMessagesIfChanged());
    }
  }

  Future<void> _initializeAutomaticRecovery() async {
    _recoveredFromNativeQueue = await _flushNativePendingSms();

    await _loadSavedMessages();
    if (!mounted) return;

    setState(() {
      _isInitializing = true;
      _statusMessage = 'Verification des permissions SMS...';
    });

    final hasPermission = await _smsService.ensureSmsPermissions();
    if (!mounted) return;

    if (!hasPermission) {
      setState(() {
        _isInitializing = false;
        _isListening = false;
        _statusMessage =
            'Permission SMS refusee. Active-la pour la recuperation automatique.';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Synchronisation des SMS existants...';
    });

    int processedCount = 0;
    try {
      final matchingMessages = await _smsService.getMatchingInboxMessages();
      for (final message in matchingMessages) {
        await _dbHelper.saveMessage(
          address: message['address']?.toString() ?? '',
          body: message['body']?.toString() ?? '',
          date: message['date']?.toString() ?? DateTime.now().toIso8601String(),
        );
        processedCount++;
      }
    } catch (e) {
      debugPrint('Erreur de synchronisation initiale SMS: $e');
    }

    await _loadSavedMessages();
    if (!mounted) return;

    _smsService.startIncomingListener(onMatchingMessage: _handleIncomingMatch);
    _startAutoRefresh();

    setState(() {
      _isInitializing = false;
      _isListening = true;
      _statusMessage =
          'Ecoute active: app ouverte + capture native en arriere-plan.';
    });

    final totalRecovered = processedCount + _recoveredFromNativeQueue;
    if (totalRecovered > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$totalRecovered SMS synchronises au lancement.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<int> _flushNativePendingSms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return 0;
    }

    try {
      final flushed = await _backgroundSmsChannel.invokeMethod<int>(
        'flushPendingSms',
      );
      return flushed ?? 0;
    } catch (e) {
      debugPrint('Impossible de vider la file native SMS: $e');
      return 0;
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(_refreshMessagesIfChanged());
    });
  }

  Future<void> _handleIncomingMatch(Map<String, dynamic> message) async {
    await _dbHelper.saveMessage(
      address: message['address']?.toString() ?? '',
      body: message['body']?.toString() ?? '',
      date: message['date']?.toString() ?? DateTime.now().toIso8601String(),
    );

    await _refreshMessagesIfChanged();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nouveau SMS sauvegarde automatiquement.'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _loadSavedMessages() async {
    final messages = await _dbHelper.getMessages();
    final filteredMessages = _applyActiveFilter(messages);
    if (!mounted) return;

    setState(() {
      _savedMessages = filteredMessages;
      _messagesSnapshot = _buildSnapshot(filteredMessages);
    });
  }

  Future<void> _refreshMessagesIfChanged() async {
    final messages = await _dbHelper.getMessages();
    final filteredMessages = _applyActiveFilter(messages);
    if (!mounted) return;

    final snapshot = _buildSnapshot(filteredMessages);
    if (snapshot == _messagesSnapshot) return;

    setState(() {
      _savedMessages = filteredMessages;
      _messagesSnapshot = snapshot;
    });
  }

  List<Map<String, dynamic>> _applyActiveFilter(
    List<Map<String, dynamic>> messages,
  ) {
    return messages
        .where(
          (message) => _smsService.isMatchingMessage(
            address: message['address']?.toString(),
            body: message['body']?.toString(),
          ),
        )
        .toList(growable: false);
  }

  String _buildSnapshot(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return '0';

    final first = messages.first;
    return '${messages.length}:${first['id'] ?? ''}:${first['date'] ?? ''}';
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
      appBar: AppBar(title: const Text('Auto SMS')),
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
                      _isListening ? 'Ecoute automatique active' : 'En attente',
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
                      'Aucun SMS correspondant a votre filtre sauvegarde.',
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
