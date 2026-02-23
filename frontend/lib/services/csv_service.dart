// --- 13. The Excel Bridge (CSV) ---
// This service converts simple lists of data into a format that 
// Microsoft Excel or Google Sheets can open easily.

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvService {
  // Takes column headers and rows, and builds a .csv file in the phone's memory
  static Future<void> exportToCsv(String fileName, List<String> columns, List<List<dynamic>> rows) async {
    // 1. Join column names with commas
    String csvData = '${columns.join(',')}\n';
    
    // 2. Wrap every cell in quotes to handle commas inside text
    for (var row in rows) {
      csvData += '${row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',')}\n';
    }

    // 3. Save the string to a temporary file on the device
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    // 4. Trigger the system "Share" dialog so the user can email or WhatsApp the file
    await Share.shareXFiles([XFile(path)], text: 'Exported Report');
  }
}
