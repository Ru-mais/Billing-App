import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfHelper {
  static Future<void> generateAndShareReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items,
    required double total,
    required String footer,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // Similar format to thermal printers
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(shopName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              if (address1.isNotEmpty) pw.Text(address1, style: const pw.TextStyle(fontSize: 12)),
              if (address2.isNotEmpty) pw.Text(address2, style: const pw.TextStyle(fontSize: 12)),
              pw.Text(phone, style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              
              pw.Text(DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 8),
              
              pw.Divider(),
              
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                   pw.Expanded(flex: 3, child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                   pw.Expanded(flex: 1, child: pw.Text('Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                   pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                ]
              ),
              pw.Divider(),

              // Items
              for (var item in items)
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text('${item['qty']}x ${item['name']}', style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('${item['price']}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('${item['total']}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                    ]
                  )
                ),
                
              pw.Divider(),
              
              // Total
              pw.Row(
                 mainAxisAlignment: pw.MainAxisAlignment.end,
                 children: [
                    pw.Text('TOTAL: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(total.toStringAsFixed(2), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                 ]
              ),
              
              pw.SizedBox(height: 16),
              
              pw.Text(footer, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
              pw.SizedBox(height: 24),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'receipt.pdf');
  }
}
