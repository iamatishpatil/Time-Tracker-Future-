import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';

class CsvService {
  static Future<void> exportToCsv(String fileName, List<String> columns, List<List<dynamic>> rows) async {
    String csvData = columns.join(',') + '\n';
    
    for (var row in rows) {
      csvData += row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(',') + '\n';
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/$fileName.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], text: 'Exported Report');
  }
}
