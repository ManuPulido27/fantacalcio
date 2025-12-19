import 'dart:io';

void main() async {
  final mergedFile = File('merged_2025_26_with_fbref_ultimate.csv');
  final fbrefFile = File('fbref_players_clean.csv');

  print('🔍 Validating ULTIMATE FIX data...\n');

  if (!await mergedFile.exists()) {
    print('❌ ERROR: merged_2025_26_with_fbref_ultimate.csv not found');
    return;
  }

  final mergedLines = await mergedFile.readAsLines();
  final fbrefLines = await fbrefFile.readAsLines();

  final mergedHeader = mergedLines[1].split(',');
  final nameIndex = mergedHeader.indexOf('Nome_Giocatore');
  final squadIndex = mergedHeader.indexOf('Squadra');
  final mpIndex = mergedHeader.indexOf('Partite_Giocate');
  final glsIndex = mergedHeader.indexOf('Gol_Totali');
  final astIndex = mergedHeader.indexOf('Assist_Totali');

  // Build FBRef lookup for validation
  final fbrefLookup = <String, List<String>>{};
  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 5) {
      final playerName = parts[1].trim();
      final squad = parts[4].trim();
      final key = '$playerName|$squad';
      fbrefLookup[key] = parts;
    }
  }

  print('=== VALIDATION RESULTS ===');

  var totalPlayers = 0;
  var matchedPlayers = 0;
  var correctData = 0;
  var incorrectData = 0;
  var sampleCorrect = <String>[];
  var sampleIncorrect = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > nameIndex && parts.length > squadIndex) {
      final playerName = parts[nameIndex].trim();
      final squad = parts[squadIndex].trim();
      final mp = parts.length > mpIndex ? parts[mpIndex].trim() : '';
      final gls = parts.length > glsIndex ? parts[glsIndex].trim() : '';
      final ast = parts.length > astIndex ? parts[astIndex].trim() : '';

      totalPlayers++;

      if (mp.isNotEmpty) {
        matchedPlayers++;

        // Find corresponding FBRef data
        final fbrefKey = '$playerName|$squad';
        final fbrefPlayer = fbrefLookup[fbrefKey];

        if (fbrefPlayer != null && fbrefPlayer.length >= 26) {
          final fbrefMp = fbrefPlayer[8].trim(); // Column 8
          final fbrefGls = fbrefPlayer[12].trim(); // Column 12 - TOTAL goals
          final fbrefAst = fbrefPlayer[13].trim(); // Column 13 - TOTAL assists

          if (mp == fbrefMp && gls == fbrefGls && ast == fbrefAst) {
            correctData++;
            if (sampleCorrect.length < 10) {
              sampleCorrect.add(
                '✅ $playerName ($squad): MP=$mp, Gls=$gls, Ast=$ast',
              );
            }
          } else {
            incorrectData++;
            if (sampleIncorrect.length < 5) {
              sampleIncorrect.add(
                '❌ $playerName ($squad): MP=$mp vs $fbrefMp, Gls=$gls vs $fbrefGls, Ast=$ast vs $fbrefAst',
              );
            }
          }
        }
      }
    }
  }

  print('📊 Data validation summary:');
  print('   Total players: $totalPlayers');
  print('   Players with FBRef data: $matchedPlayers');
  print('   Correct data entries: $correctData');
  print('   Incorrect data entries: $incorrectData');

  final accuracy = matchedPlayers > 0
      ? ((correctData / matchedPlayers) * 100).toStringAsFixed(1)
      : '0.0';
  print('   Data accuracy: $accuracy%');

  if (sampleCorrect.isNotEmpty) {
    print('\n✅ Sample correct data:');
    for (final correct in sampleCorrect) {
      print('   $correct');
    }
  }

  if (sampleIncorrect.isNotEmpty) {
    print('\n❌ Sample incorrect data:');
    for (final incorrect in sampleIncorrect) {
      print('   $incorrect');
    }
  }

  // Check specific players that were problematic
  print('\n🔍 Checking specific players:');
  final testPlayers = [
    'Pedro|Lazio',
    'Kean|Fiorentina',
    'Thuram|Inter',
    'Pulisic|Milan',
    'Dumfries|Inter',
  ];

  for (final playerKey in testPlayers) {
    final parts = playerKey.split('|');
    final playerName = parts[0];
    final squad = parts[1];

    // Find in merged data
    var mergedMp = '';
    var mergedGls = '';
    var mergedAst = '';

    for (var i = 2; i < mergedLines.length; i++) {
      final parts = mergedLines[i].split(',');
      if (parts.length > nameIndex && parts.length > squadIndex) {
        if (parts[nameIndex].trim() == playerName &&
            parts[squadIndex].trim() == squad) {
          mergedMp = parts.length > mpIndex ? parts[mpIndex].trim() : '';
          mergedGls = parts.length > glsIndex ? parts[glsIndex].trim() : '';
          mergedAst = parts.length > astIndex ? parts[astIndex].trim() : '';
          break;
        }
      }
    }

    // Find in FBRef data
    final fbrefPlayer = fbrefLookup[playerKey];
    if (fbrefPlayer != null && fbrefPlayer.length >= 26) {
      final fbrefMp = fbrefPlayer[8].trim();
      final fbrefGls = fbrefPlayer[12].trim();
      final fbrefAst = fbrefPlayer[13].trim();

      print('   $playerName ($squad):');
      print('     Merged: MP=$mergedMp, Gls=$mergedGls, Ast=$mergedAst');
      print('     FBRef:  MP=$fbrefMp, Gls=$fbrefGls, Ast=$fbrefAst');
      print(
        '     Match: ${mergedMp == fbrefMp && mergedGls == fbrefGls && mergedAst == fbrefAst ? '✅' : '❌'}',
      );
    } else {
      print('   $playerName ($squad): Not found in FBRef data');
    }
  }

  print('\n🎯 FINAL ASSESSMENT:');
  if (incorrectData == 0) {
    print('✅ PERFECT! All data is correctly merged');
    print('✅ No more per-90 vs total stats confusion');
    print('✅ Data is ready for ASTA analysis');
  } else {
    print('⚠️  $incorrectData data entries still have issues');
  }
}
