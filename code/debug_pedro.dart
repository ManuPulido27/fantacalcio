import 'dart:io';

void main() async {
  final fbrefFile = File('fbref_players_clean.csv');
  final fbrefLines = await fbrefFile.readAsLines();

  print('🔍 Debugging Pedro data...\n');

  // Find Pedro (Lazio)
  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 2 &&
        parts[1].trim() == 'Pedro' &&
        parts[4].trim() == 'Lazio') {
      print('Found Pedro (Lazio) at line $i');
      print('Total columns: ${parts.length}');
      print('');

      // Print all columns with indices
      for (var j = 0; j < parts.length; j++) {
        print('Column $j: "${parts[j]}"');
      }

      print('\nKey columns:');
      print('Column 8 (MP): "${parts[8]}"');
      print('Column 12 (Gls): "${parts[12]}"');
      print('Column 13 (Ast): "${parts[13]}"');
      break;
    }
  }
}
