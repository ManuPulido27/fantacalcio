import 'dart:io';

void main() async {
  final mergedFile = File('merged_2025_26_with_fbref.csv');
  final fantacalcioFile = File('merged_2025_26.csv');
  final fbrefFile = File('fbref_players_clean.csv');

  print('🔍 Starting comprehensive data quality validation...\n');

  if (!await mergedFile.exists()) {
    print('❌ ERROR: merged_2025_26_with_fbref.csv not found');
    return;
  }

  await performDataIntegrityChecks(mergedFile, fantacalcioFile, fbrefFile);
  await performPlayerMatchingValidation(mergedFile, fantacalcioFile, fbrefFile);
  await performFBRefDataValidation(mergedFile, fbrefFile);
  await performStatisticalValidation(mergedFile);
  await performCrossReferenceValidation(mergedFile, fantacalcioFile, fbrefFile);

  print('\n🎉 Data quality validation completed!');
}

Future<void> performDataIntegrityChecks(
  File mergedFile,
  File fantacalcioFile,
  File fbrefFile,
) async {
  print('=== DATA INTEGRITY CHECKS ===');

  final mergedLines = await mergedFile.readAsLines();
  final fantacalcioLines = await fantacalcioFile.readAsLines();
  final fbrefLines = await fbrefFile.readAsLines();

  // Check 1: Row count consistency
  final expectedRows = fantacalcioLines.length;
  final actualRows = mergedLines.length;

  if (expectedRows != actualRows) {
    print('❌ CRITICAL: Row count mismatch!');
    print('   Expected: $expectedRows rows (from Fantacalcio)');
    print('   Actual: $actualRows rows (in merged file)');
    return;
  }
  print('✅ Row count integrity: $actualRows rows match');

  // Check 2: Column count validation
  final mergedHeader = mergedLines[1].split(',');
  final fantacalcioHeader = fantacalcioLines[1].split(',');
  final fbrefHeader = fbrefLines[0].split(',');

  final expectedColumns =
      fantacalcioHeader.length + 19; // 19 FBRef columns added
  final actualColumns = mergedHeader.length;

  if (expectedColumns != actualColumns) {
    print('❌ CRITICAL: Column count mismatch!');
    print('   Expected: $expectedColumns columns');
    print('   Actual: $actualColumns columns');
    return;
  }
  print('✅ Column count integrity: $actualColumns columns match');

  // Check 3: Header structure validation
  print('\n📋 Header structure validation:');
  print('   Fantacalcio columns: ${fantacalcioHeader.length}');
  print('   FBRef columns: ${fbrefHeader.length}');
  print('   Merged columns: ${mergedHeader.length}');
  print('   Expected total: ${fantacalcioHeader.length + 19}');

  // Verify FBRef columns are properly added
  final fbrefColumns = [
    'Partite_Giocate',
    'Partite_Titolare',
    'Minuti_Giocati',
    'Partite_90_Minuti',
    'Gol_Totali',
    'Assist_Totali',
    'Gol_Plus_Assist',
    'Gol_Senza_Rigori',
    'Rigori_Realizzati',
    'Rigori_Tentati',
    'Cartellini_Gialli',
    'Cartellini_Rossi',
    'Expected_Goals',
    'Expected_Goals_Senza_Rigori',
    'Expected_Assist',
    'Expected_Goals_Plus_Assist',
    'Progressioni_Con_Palla',
    'Progressioni_Passaggi',
    'Progressioni_Ricezioni',
  ];

  var missingColumns = <String>[];
  for (final col in fbrefColumns) {
    if (!mergedHeader.contains(col)) {
      missingColumns.add(col);
    }
  }

  if (missingColumns.isNotEmpty) {
    print('❌ CRITICAL: Missing FBRef columns: ${missingColumns.join(", ")}');
  } else {
    print('✅ All FBRef columns present in merged file');
  }
}

Future<void> performPlayerMatchingValidation(
  File mergedFile,
  File fantacalcioFile,
  File fbrefFile,
) async {
  print('\n=== PLAYER MATCHING VALIDATION ===');

  final mergedLines = await mergedFile.readAsLines();
  final fantacalcioLines = await fantacalcioFile.readAsLines();
  final fbrefLines = await fbrefFile.readAsLines();

  final mergedHeader = mergedLines[1].split(',');
  final nameIndex = mergedHeader.indexOf('Nome_Giocatore');
  final squadIndex = mergedHeader.indexOf('Squadra');
  final mpIndex = mergedHeader.indexOf('Partite_Giocate');

  // Build FBRef lookup for validation
  final fbrefLookup = <String, Map<String, String>>{};
  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 5) {
      final playerName = parts[1].trim();
      final squad = parts[4].trim();
      final key = '$playerName|$squad';

      final playerData = <String, String>{};
      for (
        var j = 0;
        j < parts.length && j < fbrefLines[0].split(',').length;
        j++
      ) {
        playerData[fbrefLines[0].split(',')[j]] = parts[j].trim();
      }
      fbrefLookup[key] = playerData;
    }
  }

  var totalPlayers = 0;
  var matchedPlayers = 0;
  var unmatchedPlayers = 0;
  var suspiciousMatches = <String>[];
  var sampleMatches = <String>[];
  var sampleUnmatches = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > nameIndex && parts.length > squadIndex) {
      final playerName = parts[nameIndex].trim();
      final squad = parts[squadIndex].trim();
      final mp = parts.length > mpIndex ? parts[mpIndex].trim() : '';

      totalPlayers++;

      if (mp.isNotEmpty) {
        matchedPlayers++;

        // Validate the match by checking FBRef data
        final fbrefKey = '$playerName|$squad';
        final fbrefPlayer = fbrefLookup[fbrefKey];

        if (fbrefPlayer != null) {
          final fbrefMp = fbrefPlayer['MP'] ?? '';
          if (mp == fbrefMp) {
            if (sampleMatches.length < 10) {
              sampleMatches.add('✅ $playerName ($squad): MP=$mp');
            }
          } else {
            suspiciousMatches.add(
              '⚠️  $playerName ($squad): merged MP=$mp, FBRef MP=$fbrefMp',
            );
          }
        } else {
          suspiciousMatches.add(
            '❌ $playerName ($squad): Found in merged but not in FBRef lookup',
          );
        }
      } else {
        unmatchedPlayers++;
        if (sampleUnmatches.length < 10) {
          sampleUnmatches.add('❌ $playerName ($squad)');
        }
      }
    }
  }

  print('📊 Player matching summary:');
  print('   Total players: $totalPlayers');
  print('   Matched players: $matchedPlayers');
  print('   Unmatched players: $unmatchedPlayers');

  final matchRate = ((matchedPlayers / totalPlayers) * 100).toStringAsFixed(1);
  print('   Match rate: $matchRate%');

  if (suspiciousMatches.isNotEmpty) {
    print('\n⚠️  Suspicious matches found:');
    for (final suspicious in suspiciousMatches.take(5)) {
      print('   $suspicious');
    }
  }

  if (sampleMatches.isNotEmpty) {
    print('\n✅ Sample valid matches:');
    for (final match in sampleMatches.take(5)) {
      print('   $match');
    }
  }

  if (sampleUnmatches.isNotEmpty) {
    print('\n❌ Sample unmatched players:');
    for (final unmatch in sampleUnmatches.take(5)) {
      print('   $unmatch');
    }
  }
}

Future<void> performFBRefDataValidation(File mergedFile, File fbrefFile) async {
  print('\n=== FBRef DATA VALIDATION ===');

  final mergedLines = await mergedFile.readAsLines();
  final fbrefLines = await fbrefFile.readAsLines();

  final mergedHeader = mergedLines[1].split(',');
  final nameIndex = mergedHeader.indexOf('Nome_Giocatore');
  final squadIndex = mergedHeader.indexOf('Squadra');
  final mpIndex = mergedHeader.indexOf('Partite_Giocate');

  // Build FBRef reference data
  final fbrefReference = <String, Map<String, String>>{};
  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 5) {
      final playerName = parts[1].trim();
      final squad = parts[4].trim();
      final key = '$playerName|$squad';

      final playerData = <String, String>{};
      for (
        var j = 0;
        j < parts.length && j < fbrefLines[0].split(',').length;
        j++
      ) {
        playerData[fbrefLines[0].split(',')[j]] = parts[j].trim();
      }
      fbrefReference[key] = playerData;
    }
  }

  var dataInconsistencies = 0;
  var validData = 0;
  var sampleInconsistencies = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > nameIndex && parts.length > squadIndex) {
      final playerName = parts[nameIndex].trim();
      final squad = parts[squadIndex].trim();
      final mp = parts.length > mpIndex ? parts[mpIndex].trim() : '';

      if (mp.isNotEmpty) {
        // Find corresponding FBRef data
        Map<String, String>? fbrefPlayer;

        // Try exact match first
        fbrefPlayer = fbrefReference['$playerName|$squad'];

        // Try normalized match if exact fails
        if (fbrefPlayer == null) {
          for (final entry in fbrefReference.entries) {
            if (normalizeName(entry.key.split('|')[0]) ==
                    normalizeName(playerName) &&
                normalizeTeam(entry.key.split('|')[1]) ==
                    normalizeTeam(squad)) {
              fbrefPlayer = entry.value;
              break;
            }
          }
        }

        if (fbrefPlayer != null) {
          var isConsistent = true;
          final inconsistencies = <String>[];

          // Check key statistics
          final statsToCheck = {
            'MP': 'Partite_Giocate',
            'Starts': 'Partite_Titolare',
            'Gls': 'Gol_Totali',
            'Ast': 'Assist_Totali',
          };

          for (final entry in statsToCheck.entries) {
            final fbrefValue = fbrefPlayer[entry.key] ?? '';
            final mergedValue = parts[mergedHeader.indexOf(entry.value)].trim();

            if (fbrefValue != mergedValue) {
              isConsistent = false;
              inconsistencies.add(
                '${entry.value}: FBRef="$fbrefValue", Merged="$mergedValue"',
              );
            }
          }

          if (isConsistent) {
            validData++;
          } else {
            dataInconsistencies++;
            if (sampleInconsistencies.length < 5) {
              sampleInconsistencies.add(
                '$playerName ($squad): ${inconsistencies.join(", ")}',
              );
            }
          }
        }
      }
    }
  }

  print('📊 FBRef data consistency:');
  print('   Valid data entries: $validData');
  print('   Inconsistent entries: $dataInconsistencies');

  if (sampleInconsistencies.isNotEmpty) {
    print('\n⚠️  Sample data inconsistencies:');
    for (final inconsistency in sampleInconsistencies) {
      print('   $inconsistency');
    }
  } else {
    print('✅ All FBRef data is consistent with source');
  }
}

Future<void> performStatisticalValidation(File mergedFile) async {
  print('\n=== STATISTICAL VALIDATION ===');

  final mergedLines = await mergedFile.readAsLines();
  final mergedHeader = mergedLines[1].split(',');

  final mpIndex = mergedHeader.indexOf('Partite_Giocate');
  final glsIndex = mergedHeader.indexOf('Gol_Totali');
  final astIndex = mergedHeader.indexOf('Assist_Totali');
  final fvmIndex = mergedHeader.indexOf('FVM_Attuale');

  var playersWithFBRef = 0;
  var playersWithoutFBRef = 0;
  var mpValues = <int>[];
  var glsValues = <double>[];
  var astValues = <double>[];
  var fvmValues = <double>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > fvmIndex) {
      final fvm = double.tryParse(parts[fvmIndex].trim()) ?? 0.0;
      fvmValues.add(fvm);

      final mp = parts.length > mpIndex ? parts[mpIndex].trim() : '';
      if (mp.isNotEmpty) {
        playersWithFBRef++;
        final mpNum = int.tryParse(mp) ?? 0;
        mpValues.add(mpNum);

        if (parts.length > glsIndex) {
          final gls = double.tryParse(parts[glsIndex].trim()) ?? 0.0;
          glsValues.add(gls);
        }

        if (parts.length > astIndex) {
          final ast = double.tryParse(parts[astIndex].trim()) ?? 0.0;
          astValues.add(ast);
        }
      } else {
        playersWithoutFBRef++;
      }
    }
  }

  print('📊 Statistical summary:');
  print('   Players with FBRef data: $playersWithFBRef');
  print('   Players without FBRef data: $playersWithoutFBRef');

  if (mpValues.isNotEmpty) {
    mpValues.sort();
    print(
      '   Matches played - Min: ${mpValues.first}, Max: ${mpValues.last}, Avg: ${(mpValues.reduce((a, b) => a + b) / mpValues.length).toStringAsFixed(1)}',
    );
  }

  if (glsValues.isNotEmpty) {
    glsValues.sort();
    print(
      '   Goals per 90 - Min: ${glsValues.first.toStringAsFixed(2)}, Max: ${glsValues.last.toStringAsFixed(2)}, Avg: ${(glsValues.reduce((a, b) => a + b) / glsValues.length).toStringAsFixed(2)}',
    );
  }

  if (astValues.isNotEmpty) {
    astValues.sort();
    print(
      '   Assists per 90 - Min: ${astValues.first.toStringAsFixed(2)}, Max: ${astValues.last.toStringAsFixed(2)}, Avg: ${(astValues.reduce((a, b) => a + b) / astValues.length).toStringAsFixed(2)}',
    );
  }

  if (fvmValues.isNotEmpty) {
    fvmValues.sort();
    print(
      '   FVM - Min: ${fvmValues.first.toStringAsFixed(1)}, Max: ${fvmValues.last.toStringAsFixed(1)}, Avg: ${(fvmValues.reduce((a, b) => a + b) / fvmValues.length).toStringAsFixed(1)}',
    );
  }

  // Check for suspicious values
  var suspiciousValues = 0;
  for (final mp in mpValues) {
    if (mp > 50) {
      // More than 50 matches in a season is suspicious
      suspiciousValues++;
    }
  }

  if (suspiciousValues > 0) {
    print(
      '⚠️  WARNING: $suspiciousValues players with suspiciously high match counts (>50)',
    );
  } else {
    print('✅ All match counts are within reasonable range');
  }
}

Future<void> performCrossReferenceValidation(
  File mergedFile,
  File fantacalcioFile,
  File fbrefFile,
) async {
  print('\n=== CROSS-REFERENCE VALIDATION ===');

  final mergedLines = await mergedFile.readAsLines();
  final fantacalcioLines = await fantacalcioFile.readAsLines();
  final fbrefLines = await fbrefFile.readAsLines();

  final mergedHeader = mergedLines[1].split(',');
  final nameIndex = mergedHeader.indexOf('Nome_Giocatore');
  final squadIndex = mergedHeader.indexOf('Squadra');
  final fvmIndex = mergedHeader.indexOf('FVM_Attuale');

  // Check that all original Fantacalcio data is preserved
  var preservedData = 0;
  var corruptedData = 0;
  var sampleCorruptions = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final mergedParts = mergedLines[i].split(',');
    final fantacalcioParts = fantacalcioLines[i].split(',');

    if (mergedParts.length > fvmIndex && fantacalcioParts.length > 11) {
      final mergedFvm = mergedParts[fvmIndex].trim();
      final originalFvm = fantacalcioParts[11].trim();

      if (mergedFvm == originalFvm) {
        preservedData++;
      } else {
        corruptedData++;
        if (sampleCorruptions.length < 5) {
          final playerName = mergedParts[nameIndex].trim();
          final squad = mergedParts[squadIndex].trim();
          sampleCorruptions.add(
            '$playerName ($squad): Original FVM=$originalFvm, Merged FVM=$mergedFvm',
          );
        }
      }
    }
  }

  print('📊 Data preservation check:');
  print('   Preserved data entries: $preservedData');
  print('   Corrupted data entries: $corruptedData');

  if (sampleCorruptions.isNotEmpty) {
    print('\n❌ Sample data corruptions:');
    for (final corruption in sampleCorruptions) {
      print('   $corruption');
    }
  } else {
    print('✅ All original Fantacalcio data is preserved');
  }

  // Check for duplicate players
  final playerKeys = <String, int>{};
  var duplicates = 0;

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > nameIndex && parts.length > squadIndex) {
      final playerName = parts[nameIndex].trim();
      final squad = parts[squadIndex].trim();
      final key = '$playerName|$squad';

      playerKeys[key] = (playerKeys[key] ?? 0) + 1;
      if (playerKeys[key]! > 1) {
        duplicates++;
      }
    }
  }

  if (duplicates > 0) {
    print('❌ CRITICAL: $duplicates duplicate players found!');
    final duplicateEntries = playerKeys.entries
        .where((e) => e.value > 1)
        .toList();
    for (final dup in duplicateEntries.take(3)) {
      print('   "${dup.key}" appears ${dup.value} times');
    }
  } else {
    print('✅ No duplicate players found');
  }
}

String normalizeName(String name) {
  return name
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('-', '')
      .replaceAll('.', '')
      .replaceAll("'", '')
      .replaceAll('à', 'a')
      .replaceAll('è', 'e')
      .replaceAll('é', 'e')
      .replaceAll('ì', 'i')
      .replaceAll('ò', 'o')
      .replaceAll('ù', 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');
}

String normalizeTeam(String team) {
  return team
      .toLowerCase()
      .replaceAll(' ', '')
      .replaceAll('-', '')
      .replaceAll('.', '');
}
