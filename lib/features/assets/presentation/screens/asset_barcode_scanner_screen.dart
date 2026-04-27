import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../providers/asset_providers.dart';
import 'asset_detail_screen.dart';

class AssetBarcodeScannerScreen extends ConsumerStatefulWidget {
  const AssetBarcodeScannerScreen({super.key});

  @override
  ConsumerState<AssetBarcodeScannerScreen> createState() =>
      _AssetBarcodeScannerScreenState();
}

class _AssetBarcodeScannerScreenState
    extends ConsumerState<AssetBarcodeScannerScreen> {
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final barcode = capture.barcodes.firstOrNull?.rawValue;
    if (barcode == null || barcode.isEmpty) return;

    _handled = true;

    final asset = await ref.read(assetRepositoryProvider).getAssetByBarcode(barcode);

    if (!mounted) return;

    if (asset != null && asset.assetId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AssetDetailScreen(
              assetId: asset.assetId!, localAsset: asset),
        ),
      );
    } else {
      // Asset not found — prompt for provisional registration.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Asset Not Found'),
          content: Text(
              'No asset with barcode "$barcode" in local database.\n\n'
              'Register as a provisional asset?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Register Provisional'),
            ),
          ],
        ),
      );

      if (mounted) {
        if (confirmed == true) {
          Navigator.of(context).pop(); // Back to list — picker handles form
        } else {
          setState(() => _handled = false); // Allow next scan
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Asset Barcode')),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Point camera at asset barcode',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
