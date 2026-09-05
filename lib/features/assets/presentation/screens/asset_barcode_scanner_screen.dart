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

    final asset = await ref
        .read(assetRepositoryProvider)
        .getAssetByBarcode(barcode);

    if (!mounted) return;

    if (asset != null && asset.assetId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              AssetDetailScreen(assetId: asset.assetId!, localAsset: asset),
        ),
      );
    } else {
      // Asset not found. Registration is the office's, so there is nothing
      // to offer here beyond telling the technician what happened — and that
      // a machine missing from the tablet is a question for the office, not a
      // gap the technician can fill.
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Asset Not Found'),
          content: Text(
            'No asset with barcode "$barcode" has synced to this device. '
            'If the equipment is new, the office needs to register it before '
            'it can be worked on.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      if (mounted) {
        setState(() => _handled = false); // Allow next scan
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
                  horizontal: 20,
                  vertical: 10,
                ),
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
