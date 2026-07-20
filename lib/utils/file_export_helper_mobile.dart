import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareFile(String content, String fileName) async {
  final directory = await getTemporaryDirectory();
  final path = "${directory.path}/$fileName";
  final file = File(path);
  await file.writeAsString(content);
  await Share.shareXFiles([XFile(path)], text: fileName);
}
