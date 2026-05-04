
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

void main() {
  runApp(const NfcKitApp());
}

class NfcKitApp extends StatelessWidget {
  const NfcKitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const NfcReaderScreen(),
    );
  }
}

class NfcReaderScreen extends StatefulWidget {
  const NfcReaderScreen({super.key});

  @override
  State<NfcReaderScreen> createState() => _NfcReaderScreenState();
}

class _NfcReaderScreenState extends State<NfcReaderScreen> {
  String _status = 'Ready to Scan';
  String _result = 'No data yet';
  bool _isScanning = false;

  Future<void> _startScanning() async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _status = 'Scanning...';
      _result = 'Hold your card near the device';
    });

    try {
      final availability = await NfcManager.instance.checkAvailability();
      if (availability != NfcAvailability.enabled) {
        throw Exception('NFC is not available or is turned off.');
      }

      await NfcManager.instance.startSession(
        pollingOptions: {
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Hold your card near the top of your iPhone',
        onDiscovered: (NfcTag tag) async {
          final androidTag = NfcTagAndroid.from(tag);
          final ndef = Ndef.from(tag);
          final log = StringBuffer();
          log.writeln('Tag discovered');
          log.writeln('Type: ${tag.runtimeType}');

          if (androidTag != null) {
            log.writeln('Tag ID: ${_bytesToHex(androidTag.id)}');
            log.writeln('Tech list: ${androidTag.techList.join(', ')}');
          }

          if (ndef == null) {
            log.writeln('NDEF: not available on this tag');
          } else {
            log.writeln('NDEF writable: ${ndef.isWritable}');
            log.writeln('NDEF max size: ${ndef.maxSize} bytes');
            log.writeln('NDEF additional data:');
            log.writeln(
              const JsonEncoder.withIndent('  ').convert(
                _sanitize(ndef.additionalData),
              ),
            );

            final message = ndef.cachedMessage ?? await ndef.read();
            log.writeln('NDEF message: ${message ?? 'null'}');
          }

          if (!mounted) {
            return;
          }

          setState(() {
            _status = 'Success!';
            _result = log.toString();
          });

          await NfcManager.instance.stopSession(
            alertMessageIos: 'Scan completed',
          );
          if (!mounted) {
            return;
          }
          setState(() => _isScanning = false);
        },
      );
    } catch (e) {
      try {
        await NfcManager.instance.stopSession(
          errorMessageIos: 'Scan failed',
        );
      } catch (_) {}

      setState(() {
        _status = 'Error';
        _result = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  static Object? _sanitize(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), _sanitize(item)));
    }
    if (value is Iterable) {
      return value.map(_sanitize).toList();
    }
    if (value is num || value is bool || value == null) {
      return value;
    }
    return value.toString();
  }

  static String _bytesToHex(List<int> bytes) {
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void dispose() {
    NfcManager.instance.stopSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC Reader')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Indicator
            Card(
              color: _isScanning ? Colors.orange.shade50 : Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Status: $_status',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Result Display
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _result,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Scan Button
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _startScanning,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              icon: _isScanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.nfc),
              label: Text(_isScanning ? 'Waiting for Card...' : 'Start NFC Scan'),
            ),
          ],
        ),
      ),
    );
  }
}