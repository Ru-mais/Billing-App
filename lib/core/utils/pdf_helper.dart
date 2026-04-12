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
    double? totalCash,
    double? totalQR,
    required double totalExpense,
    required List<Map<String, dynamic>> topItems,
    required List<Map<String, dynamic>> transactions,
    bool isSimple = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        ),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(reportTitle, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                      pw.Text('Report Period: $dateString', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                    ]
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                    ]
                  ),
                ]
              )
            ),
            pw.SizedBox(height: 20),

            // Financial Summary Table
            pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 10),
              data: [
                ['Metric', 'Amount (Rs.)'],
                ['Total Revenue', totalRevenue.toStringAsFixed(2)],
                ['Total Expense', totalExpense.toStringAsFixed(2)],
                ['Net Profit/Loss', (totalRevenue - totalExpense).toStringAsFixed(2)],
                if (totalCash != null) ['Cash Income', totalCash.toStringAsFixed(2)],
                if (totalQR != null) ['QR Income', totalQR.toStringAsFixed(2)],
                ['Total Transactions', totalBills.toString()],
              ],
            ),
            pw.SizedBox(height: 24),

            // Top Performing Items
            if (topItems.isNotEmpty) ...[
              pw.Text('TOP PERFORMING PRODUCTS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
                cellStyle: const pw.TextStyle(fontSize: 9),
                data: [
                  ['Product Name', 'Quantity Sold'],
                  ...topItems.take(5).map((item) => [item['name'], item['qty'].toString()]),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // Detailed Ledger
            pw.Text('TRANSACTION LEDGER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: const pw.TextStyle(fontSize: 8),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100, width: 0.5))),
              data: <List<String>>[
                <String>['Date / Time', 'Description', 'Amount (Rs)'],
                ...transactions.map((tz) => [tz['time'].toString(), tz['items'].toString(), tz['total'].toString()]),
              ],
            ),
          ];
        },
      ),
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

  static pw.Widget _buildSummaryCard(String title, double value, PdfColor bgColor, PdfColor textColor, {double? totalCash, double? totalQR}) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: bgColor,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: textColor, width: 0.5),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 8, color: textColor, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Rs. ${value.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor)),
            if (totalCash != null && totalQR != null) ...[
              pw.SizedBox(height: 4),
            pw.Text('C: Rs. ${totalCash.toStringAsFixed(0)} | Q: Rs. ${totalQR.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 7, color: textColor)),
            ]
          ],
        ),
      ),
    );
  }

  static Future<void> generateProductLabelPdf({
    required String barcode,
    required int copies,
  }) async {
    final pdf = pw.Document();

    for (int i = 0; i < copies; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(16),
                child: pw.BarcodeWidget(
                  data: barcode,
                  barcode: pw.Barcode.code128(),
                  width: 160,
                  height: 60,
                  drawText: true,
                  textStyle: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => await pdf.save(),
        name: 'label_$barcode.pdf',
      );
    } catch (e) {
      debugPrint('PDF layout error: $e');
      rethrow;
    }
  }
}
