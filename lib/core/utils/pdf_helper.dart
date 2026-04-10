import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

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

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await pdf.save(),
        name: 'receipt.pdf',
      );
    } catch (e) {
      debugPrint('PDF layout error: $e');
      rethrow;
    }
  }

  static Future<void> generateReportSummaryPdf({
    required String reportTitle,
    required String fileNamePrefix,
    required String shopName,
    required String dateString,
    required double totalRevenue,
    required int totalBills,
    required List<Map<String, dynamic>> topItems,
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(reportTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(shopName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                ]
              )
            ),
            pw.Text('Date: $dateString', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 24),

            // Summary Boxes
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.blue200)
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL REVENUE', style: pw.TextStyle(fontSize: 10, color: PdfColors.blue900)),
                        pw.SizedBox(height: 4),
                        pw.Text('Rs. ${totalRevenue.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      ]
                    )
                  )
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                      border: pw.Border.all(color: PdfColors.green200)
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL BILLS', style: pw.TextStyle(fontSize: 10, color: PdfColors.green900)),
                        pw.SizedBox(height: 4),
                        pw.Text('$totalBills', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                      ]
                    )
                  )
                )
              ]
            ),
            pw.SizedBox(height: 32),

            // Custom Simple Bar Chart Section
            if (topItems.isNotEmpty) ...[
              pw.Text('Top Selling Items Breakdown', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
              pw.SizedBox(height: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300)),
                child: pw.Column(
                  children: topItems.map((item) {
                     final maxQty = (topItems[0]['qty'] as int).toDouble();
                     final ratio = (item['qty'] as int) / (maxQty > 0 ? maxQty : 1);
                     
                     return pw.Padding(
                       padding: const pw.EdgeInsets.symmetric(vertical: 6),
                       child: pw.Row(
                         children: [
                           pw.SizedBox(width: 120, child: pw.Text('${item['name']}', maxLines: 1, style: const pw.TextStyle(fontSize: 10))),
                           pw.SizedBox(width: 16),
                           pw.Expanded(
                             child: pw.Container(
                               height: 12,
                               alignment: pw.Alignment.centerLeft,
                               child: pw.Container(
                                 width: ratio * 200, // Visual representation scaled based on max element
                                 height: 12,
                                 decoration: const pw.BoxDecoration(
                                   color: PdfColors.indigo400,
                                   borderRadius: pw.BorderRadius.all(pw.Radius.circular(2))
                                 )
                               )
                             )
                           ),
                           pw.SizedBox(width: 8),
                           pw.Text('${item['qty']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))
                         ]
                       )
                     );
                  }).toList()
                )
              ),
              pw.SizedBox(height: 32),
            ],

            // Ledger
            pw.Text('Transactions Ledger', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
               context: context,
               cellAlignment: pw.Alignment.centerLeft,
               headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
               headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
               cellStyle: const pw.TextStyle(fontSize: 10),
               data: <List<String>>[
                 <String>['Date / Time', 'Volume', 'Total (Rs)'],
                 ...transactions.map((tz) => [tz['time'].toString(), tz['items'].toString(), tz['total'].toString()]),
               ]
            ),
          ];
        }
      )
    );

    // Generate PDF securely
    try {
      final formattedSafeDate = dateString.replaceAll('/', '-');
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await pdf.save(),
        name: '${fileNamePrefix}_$formattedSafeDate.pdf',
      );
    } catch (e) {
      debugPrint('PDF layout error: $e');
      rethrow;
    }
  }
}
