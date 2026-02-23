// --- 12. The PDF Print Station ---
// This service doesn't show any UI. Instead, it takes raw data and 
// "draws" it onto a PDF document that can be shared or printed.

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PdfService {
  // Generates a simple table of attendance for one employee
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
          // Every piece of data is mapped to a row in a PDF table
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

    // This opens the system print dialog automatically
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

  // Generates a wide-format report of absolute salary numbers for the whole company
  static Future<void> generatePayrollReport(List<dynamic> payroll) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, // Wide layout for many columns
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
          // Total sum calculation at the bottom of the table
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

  // The Masterpiece: Generating a professional, high-fidelity payslip
  static Future<void> generateIndividualPayslip(Map<String, dynamic> payslip, Map<String, dynamic> user, Map<String, dynamic> company) async {
    final pdf = pw.Document();
    
    final monthYear = DateFormat('MMMM yyyy').format(DateTime(payslip['year'], payslip['month']));
    final companyName = company['companyName'] ?? 'Company';
    
    // Parse values to ensure they are doubles
    final basic = double.parse(payslip['basicSalary'].toString());
    final allowances = double.parse(payslip['allowances'].toString());
    final deductions = double.parse(payslip['deductions'].toString());
    final net = double.parse(payslip['netSalary'].toString());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Company Branding Section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(companyName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                    pw.Text('Payslip for $monthYear', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
                  ],
                ),
                pw.Text('CONFIDENTIAL', style: pw.TextStyle(fontSize: 10, color: PdfColors.red, letterSpacing: 2)),
              ],
            ),
            
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 20),

            // Employee Details
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Employee Name:', style: pw.TextStyle(color: PdfColors.grey600)),
                    pw.Text('${user['fullName']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Text('Email:', style: pw.TextStyle(color: PdfColors.grey600)),
                    pw.Text('${user['email']}'),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Designation/Role:', style: pw.TextStyle(color: PdfColors.grey600)),
                    pw.Text('${user['role']}'),
                    pw.SizedBox(height: 10),
                    pw.Text('Generated On:', style: pw.TextStyle(color: PdfColors.grey600)),
                    pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now())),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 30),

            // Earnings vs Deductions Split Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.deepPurple),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Earnings', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount (₹)', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Deductions', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Amount (₹)', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold))),
                  ]
                ),
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Basic Salary\n\nAllowances/Bonus')),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${basic.toStringAsFixed(2)}\n\n${allowances.toStringAsFixed(2)}')),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Taxes/Penalties')),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${deductions.toStringAsFixed(2)}')),
                  ]
                ),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Gross Earnings', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${(basic + allowances).toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total Deductions', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${deductions.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                  ]
                ),
              ]
            ),

            pw.SizedBox(height: 30),

            // The BIG Net Payable Card
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.deepPurple, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                color: PdfColors.purple50,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET PAYABLE SALARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                  pw.Text('₹ ${net.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.deepPurple)),
                ]
              )
            ),
            
            pw.Spacer(),
            
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text('This is a computer generated document and does not require a signature.', 
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ),
          ]
        ),
      ),
    );

    // Give it a professional filename and send to the system printer
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Payslip_${user['fullName']}_$monthYear.pdf'
    );
  }
}
