import 'dart:io';

void main() async {
  final fbrefFile = File('fbref_players_clean.csv');
  final fbrefLines = await fbrefFile.readAsLines();

  print('🔍 Testing Pedro matching...\n');

  // Build FBRef lookup
  final fbrefData = <String, List<String>>{};
  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 2) {
      final playerName = parts[1].trim();
      final squad = parts[4].trim();
      final key = '$playerName|$squad';
      fbrefData[key] = parts;
    }
  }

  // Test Pedro entries
  final testKeys = ['Pedro|Lazio', 'Zè Pedro|Cagliari'];

  for (final key in testKeys) {
    print('Testing: $key');
    final fbrefPlayer = fbrefData[key];
    if (fbrefPlayer != null) {
      print('  Found: ${fbrefPlayer[1]} (${fbrefPlayer[4]})');
      print(
        '  MP: ${fbrefPlayer[8]}, Gls: ${fbrefPlayer[12]}, Ast: ${fbrefPlayer[13]}',
      );
    } else {
      print('  Not found');
    }
    print('');
  }

  // Check all Pedro entries in FBRef
  print('All Pedro entries in FBRef:');
  for (final entry in fbrefData.entries) {
    if (entry.key.contains('Pedro')) {
      final parts = entry.value;
      print(
        '  ${parts[1]} (${parts[4]}) - MP: ${parts[8]}, Gls: ${parts[12]}, Ast: ${parts[13]}',
      );
    }
  }
}
