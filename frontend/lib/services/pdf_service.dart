import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';


class PdfService {
  static Future<void> generateAttendanceReport(String userName, List<dynamic> history, {List<dynamic> holidays = const []}) async {
    final pdf = pw.Document();
    final holidayDates = holidays.isNotEmpty ? Set<String>.from(holidays.map((h) => h['date'])) : <String>{};

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
            headers: ['Date', 'Check In', 'Check Out', 'Location', 'Status', 'Note'],
            data: history.map((record) {
              final checkIn = DateTime.parse(record['checkInTime']).toLocal();
              final dateStr = DateFormat('yyyy-MM-dd').format(checkIn);
              final checkOut = record['checkOutTime'] != null 
                  ? DateTime.parse(record['checkOutTime']).toLocal() 
                  : null;
              
              String note = holidayDates.contains(dateStr) ? 'Holiday' : '';
              String location = record['checkInAddress'] ?? '-';
              if (location.length > 30) location = '${location.substring(0, 27)}...';
              
              return [
                DateFormat('MMM d, y').format(checkIn),
                DateFormat('hh:mm a').format(checkIn),
                checkOut != null ? DateFormat('hh:mm a').format(checkOut) : '-',
                location,
                checkOut != null ? 'Completed' : 'Active',
                note,
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  static Future<void> generateAdminAttendanceReport(List<dynamic> attendance) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Master Attendance Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                pw.Text(DateFormat('MMM d, y').format(DateTime.now())),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['Employee', 'Date', 'In', 'Out', 'Status'],
            data: attendance.map((r) => [
              r['fullName'] ?? '-',
              DateFormat('MMM d').format(DateTime.parse(r['checkInTime']).toLocal()),
              DateFormat('hh:mm a').format(DateTime.parse(r['checkInTime']).toLocal()),
              r['checkOutTime'] != null ? DateFormat('hh:mm a').format(DateTime.parse(r['checkOutTime']).toLocal()) : '-',
              r['status'] ?? 'Present'
            ]).toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  static Future<void> generatePayrollReport(List<dynamic> payroll) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Monthly Payroll Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
          ),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green900),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['Employee', 'Base Sal.', 'Days', 'Worked Hrs', 'OT Pay', 'Penalties', 'Net Salary'],
            data: payroll.map((r) => [
              r['fullName'] ?? '-',
              '₹${r['salary']}',
              r['workingDays'] ?? '22',
              (double.parse(r['totalHours'].toString()).toStringAsFixed(1)),
              '₹${r['overtimePay']}',
              '₹${r['latePenalty']}',
              '₹${r['netSalary']}'
            ]).toList(),
          ),
          pw.SizedBox(height: 30),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Total Payroll Liability: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('₹${payroll.fold(0.0, (sum, item) => sum + double.parse(item['netSalary'].toString())).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}

