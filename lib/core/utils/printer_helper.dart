import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'pdf_helper.dart';

class PrinterHelper {
  // Singleton
  static final PrinterHelper _instance = PrinterHelper._internal();
  factory PrinterHelper() => _instance;
  PrinterHelper._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  Future<bool> checkPermission() async {
    if (kIsWeb) return true;
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    if (kIsWeb) return [];
    try {
      final List<BluetoothInfo> list =
          await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    if (kIsWeb) return false;
    try {
      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    if (kIsWeb) return true;
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = !result;
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> printText(String text) async {
    if (kIsWeb || !_isConnected) return;
    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];
      bytes += generator.reset();
      bytes += generator.text(text);
      bytes += generator.feed(2);
      bytes += generator.cut();
      await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      debugPrint('Error printing text: $e');
    }
  }

  Future<void> printReceipt({
    required String shopName,
    required String invoiceNo,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items, // Name, Qty, Price, Total
    required double netAmount,
    required double discountAmount,
    required double total,
    required String footer,
    String? gstIn,
    String? customerName,
    String? customerPhone,
    String? logoPath,
  }) async {
    if (kIsWeb || !_isConnected) return;

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.reset();

    // LOGO PRINTING
    if (logoPath != null && logoPath.isNotEmpty && !kIsWeb) {
      try {
        final File file = File(logoPath);
        if (await file.exists()) {
          final Uint8List imageBytes = await file.readAsBytes();
          img.Image? image = img.decodeImage(imageBytes);
          if (image != null) {
            // Resize to fit nicely on 58mm paper (~384px max)
            img.Image resized = img.copyResize(image, width: 300);
            // Ensure B&W or grayscale for thermal printers
            img.Image grayscale = img.grayscale(resized);
            bytes += generator.imageRaster(grayscale, align: PosAlign.center);
            bytes += generator.feed(1); // Small gap after logo
          }
        }
      } catch (e) {
        debugPrint('Error printing logo: $e');
      }
    }

    // Shop Name
    bytes += generator.text(shopName,
        styles: PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ));

    // GSTIN
    if (gstIn != null && gstIn.isNotEmpty) {
      bytes += generator.text('GSTIN: $gstIn',
          styles: PosStyles(align: PosAlign.center, bold: true));
    }

    // Address & Phone
    if (address1.isNotEmpty) {
      bytes += generator.text(address1,
          styles: PosStyles(align: PosAlign.center));
    }
    if (address2.isNotEmpty) {
      bytes += generator.text(address2,
          styles: PosStyles(align: PosAlign.center));
    }
    bytes += generator.text('Tel: $phone',
        styles: PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);

    // Customer Info
    if (customerName != null && customerName.isNotEmpty) {
      bytes += generator.text('Customer: $customerName');
    }
    if (customerPhone != null && customerPhone.isNotEmpty) {
      bytes += generator.text('Phone: $customerPhone');
    }

    // Date and Invoice
    String formattedDate =
        DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    bytes += generator.text(formattedDate);
    bytes += generator.text('Invoice: $invoiceNo');

    bytes += generator.text('--------------------------------');

    // Header
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6),
      PosColumn(text: 'Qty/Price', width: 3, styles: PosStyles(align: PosAlign.right)),
      PosColumn(text: 'Total', width: 3, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.text('--------------------------------');

    // Items
    for (var item in items) {
      String name = item['name'].toString();
      String qty = item['qty'].toString();
      String price = item['price'].toString();
      String totalItem = item['total'].toString();

      bytes += generator.row([
        PosColumn(text: name, width: 6),
        PosColumn(text: '$qty x $price', width: 3, styles: PosStyles(align: PosAlign.right)),
        PosColumn(text: totalItem, width: 3, styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.text('--------------------------------');

    // Totals
    bytes += generator.row([
      PosColumn(text: 'NET AMOUNT', width: 8, styles: PosStyles(align: PosAlign.right)),
      PosColumn(text: netAmount.toStringAsFixed(2), width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'DISCOUNT', width: 8, styles: PosStyles(align: PosAlign.right)),
      PosColumn(text: '-${discountAmount.toStringAsFixed(2)}', width: 4, styles: PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 8, styles: PosStyles(align: PosAlign.right, bold: true)),
      PosColumn(text: total.toStringAsFixed(2), width: 4, styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += generator.feed(1);

    // Footer
    bytes += generator.text(footer,
        styles: PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> printProductLabel({
    required String name,
    required String barcode,
    required double price,
    required int copies,
  }) async {
    if (kIsWeb || !_isConnected) {
      await PdfHelper.generateProductLabelPdf(barcode: barcode, copies: copies);
      return;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    for (int i = 0; i < copies; i++) {
        bytes += generator.reset();
        bytes += generator.text(name, styles: PosStyles(align: PosAlign.center, bold: true));
        bytes += generator.barcode(Barcode.code128(barcode.codeUnits));
        bytes += generator.text('Price: ${price.toStringAsFixed(2)}', styles: PosStyles(align: PosAlign.center));
        bytes += generator.feed(2);
        bytes += generator.cut();
    }

    await PrintBluetoothThermal.writeBytes(bytes);
  }
}
