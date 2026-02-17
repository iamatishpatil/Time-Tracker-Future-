import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';


class PdfService {
  static Future<void> generateAttendanceReport(String userName, List<dynamic> history) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('MMM d, y').format(DateTime.now()), style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text('Employee: $userName', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.center,
            },
            columnWidths: {
              0: const pw.FlexColumnWidth(1.5),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(1),
            },
            headers: ['Date', 'Check In', 'Check Out', 'Location', 'Status'],
            data: history.map((record) {
              final checkIn = DateTime.parse(record['checkInTime']).toLocal();
              final checkOut = record['checkOutTime'] != null 
                  ? DateTime.parse(record['checkOutTime']).toLocal() 
                  : null;
              
              String location = record['checkInAddress'] ?? '-';
              // Truncate location if too long
              if (location.length > 40) {
                location = '${location.substring(0, 37)}...';
              }
              
              return [
                DateFormat('MMM d, y').format(checkIn),
                DateFormat('hh:mm a').format(checkIn),
                checkOut != null ? DateFormat('hh:mm a').format(checkOut) : '-',
                location,
                checkOut != null ? 'Completed' : 'Active',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
