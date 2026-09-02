import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '/core/api_config.dart';

class PassStickerPage extends StatefulWidget {
  final int passId;

  const PassStickerPage({super.key, required this.passId});

  @override
  State<PassStickerPage> createState() => _PassStickerPageState();
}

class _PassStickerPageState extends State<PassStickerPage> {
  final GlobalKey _stickerKey = GlobalKey();

  bool _loading = true;
  String? _error;

  String _passNo = '';
  String _empType = '';
  String _gateNo = '';
  String _parkingToBeUsed = '';

  @override
  void initState() {
    super.initState();
    _loadPass();
  }

  Future<void> _loadPass() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http
          .get(
            Uri.parse('${ApiConfig.passList}/${widget.passId}'),
            headers: {
              'x-api-key': ApiConfig.apiKey,
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(milliseconds: 12000));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() {
          _passNo = (data['passNo'] ?? '').toString();
          _empType = (data['empType'] ?? '').toString().trim().toUpperCase();
          _gateNo = (data['gateNo'] ?? '').toString();
          _parkingToBeUsed = (data['parkingToBeUsed'] ?? '').toString();
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Unable to load sticker details. HTTP ${res.statusCode}';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Unable to load sticker details (Network Error)';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1E3A),
        foregroundColor: Colors.white,
        title: const Text('Pass Sticker'),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: Color(0xFF0B1E3A))
            : _error != null
            ? _buildError()
            : SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RepaintBoundary(key: _stickerKey, child: _buildSticker()),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _printSticker,
                      icon: const Icon(Icons.print),
                      label: const Text('Print Sticker'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B1E3A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 34),
          const SizedBox(height: 10),
          Text(
            _error ?? 'Error',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _loadPass, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildSticker() {
    final isHeg = _empType == 'HEG';

    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isHeg ? const Color(0xFFFFEB00) : const Color(0xFFD91C1C),
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              Image.asset(
                'assets/images/heg_logo.jpg',
                width: 58,
                height: 38,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 8),
              Text(
                isHeg ? 'VEHICLE ENTRY PASS' : 'CONTRACTOR',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: Colors.black,
                ),
              ),
              if (!isHeg) ...[
                const SizedBox(height: 2),
                const Text(
                  'VEHICLE ENTRY PASS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Arial',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    color: Colors.black,
                  ),
                ),
              ],
              const SizedBox(height: 5),
              const Text(
                'HEG LTD.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 22),
              _rowText('PASS NO', _passNo),
              const SizedBox(height: 4),
              _rowText('GATE', _gateNo),
              const SizedBox(height: 4),
              Text(
                _parkingToBeUsed,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowText(String label, String value) {
    return Text(
      '$label:$value',
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontFamily: 'Arial',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.black,
      ),
    );
  }

  Future<void> _printSticker() async {
    try {
      final boundary =
          _stickerKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sticker_$_passNo.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Sticker for Pass $_passNo');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to print sticker: $e')));
    }
  }
}
