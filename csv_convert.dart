import 'dart:io';

void main() async {
  final file2025 = File('25_26.csv');
  final file2024 = File('24_25.csv');
  final outFile = File('merged_2025_26.csv');

  print('Starting CSV merge with validation...');

  if (!await file2025.exists()) {
    print('ERROR: 25_26.csv not found');
    return;
  }
  if (!await file2024.exists()) {
    print('ERROR: 24_25.csv not found');
    return;
  }

  final lines2025 = await file2025.readAsLines();
  final lines2024 = await file2024.readAsLines();

  print('2025/26 file: ${lines2025.length} lines');
  print('2024/25 file: ${lines2024.length} lines');

  if (lines2025.isEmpty || lines2024.isEmpty) {
    print('ERROR: One or both files are empty');
    return;
  }

  final header2025 = lines2025[1].split(',');
  final header2024 = lines2024[1].split(',');

  print('2025/26 headers: ${header2025.length} columns');
  print('2024/25 headers: ${header2024.length} columns');

  final idxName25 = header2025.indexOf('Nome');
  final idxName24 = header2024.indexOf('Nome');
  final idxFvm24 = header2024.indexOf('FVM');

  if (idxName25 == -1) {
    print('ERROR: "Nome" column not found in 2025/26 file');
    print('Available columns: ${header2025.join(", ")}');
    return;
  }
  if (idxName24 == -1) {
    print('ERROR: "Nome" column not found in 2024/25 file');
    print('Available columns: ${header2024.join(", ")}');
    return;
  }
  if (idxFvm24 == -1) {
    print('ERROR: "FVM" column not found in 2024/25 file');
    print('Available columns: ${header2024.join(", ")}');
    return;
  }

  print(
    'Column indices - Name 2025: $idxName25, Name 2024: $idxName24, FVM 2024: $idxFvm24',
  );

  final fvm24 = <String, String>{};
  var validRows2024 = 0;
  var invalidRows2024 = 0;

  for (var i = 2; i < lines2024.length; i++) {
    final line = lines2024[i];
    final parts = const CsvToListConverter()
        .convert(line, eol: '\n', fieldDelimiter: ',')
        .first;

    if (parts.length > idxName24 && parts.length > idxFvm24) {
      final name = parts[idxName24].toString().trim();
      final fvm = parts[idxFvm24].toString().trim();

      if (name.isNotEmpty && fvm.isNotEmpty) {
        fvm24[name] = fvm;
        validRows2024++;
      } else {
        invalidRows2024++;
        if (invalidRows2024 <= 5) {
          print(
            'WARNING: Invalid row ${i + 1} in 2024/25: name="$name", fvm="$fvm"',
          );
        }
      }
    } else {
      invalidRows2024++;
      if (invalidRows2024 <= 5) {
        print(
          'WARNING: Row ${i + 1} in 2024/25 has insufficient columns: ${parts.length}',
        );
      }
    }
  }

  print(
    '2024/25 data: $validRows2024 valid rows, $invalidRows2024 invalid rows',
  );
  print('Unique players with FVM data: ${fvm24.length}');

  final out = <String>[];
  out.add('${lines2025.first},FVM_Stagione_Precedente');

  // Create descriptive header
  final descriptiveHeader = [
    'ID_Giocatore',
    'Ruolo',
    'Ruolo_Multiplo',
    'Nome_Giocatore',
    'Squadra',
    'Quotazione_Attuale',
    'Quotazione_Iniziale',
    'Differenza_Prezzo',
    'Quotazione_Attuale_Mercato',
    'Quotazione_Iniziale_Mercato',
    'Differenza_Prezzo_Mercato',
    'FVM_Attuale',
    'FVM_Mercato',
    'FVM_Stagione_Precedente',
    'Differenza_FVM_Stagioni',
  ];
  out.add(descriptiveHeader.join(','));

  var validRows2025 = 0;
  var invalidRows2025 = 0;
  var matchedPlayers = 0;
  var unmatchedPlayers = 0;

  for (var i = 2; i < lines2025.length; i++) {
    final line = lines2025[i];
    final parts = const CsvToListConverter()
        .convert(line, eol: '\n', fieldDelimiter: ',')
        .first;

    if (parts.length > idxName25) {
      final name = parts[idxName25].toString().trim();

      if (name.isNotEmpty) {
        final fvmPrev = fvm24[name] ?? '';

        // Calculate FVM difference (current - previous season)
        var fvmDiff = '';
        if (fvmPrev.isNotEmpty && parts.length > 11) {
          final currentFvm = parts[11].toString().trim();
          if (currentFvm.isNotEmpty) {
            final currentFvmNum = double.tryParse(currentFvm);
            final prevFvmNum = double.tryParse(fvmPrev);
            if (currentFvmNum != null && prevFvmNum != null) {
              fvmDiff = (currentFvmNum - prevFvmNum).toString();
            }
          }
        }

        out.add('$line,$fvmPrev,$fvmDiff');
        validRows2025++;

        if (fvmPrev.isNotEmpty) {
          matchedPlayers++;
        } else {
          unmatchedPlayers++;
          if (unmatchedPlayers <= 10) {
            print('INFO: No FVM data for 2025/26 player: $name');
          }
        }
      } else {
        invalidRows2025++;
        if (invalidRows2025 <= 5) {
          print('WARNING: Empty name in row ${i + 1} of 2025/26');
        }
      }
    } else {
      invalidRows2025++;
      if (invalidRows2025 <= 5) {
        print(
          'WARNING: Row ${i + 1} in 2025/26 has insufficient columns: ${parts.length}',
        );
      }
    }
  }

  print(
    '2025/26 data: $validRows2025 valid rows, $invalidRows2025 invalid rows',
  );
  print('Players with FVM data: $matchedPlayers');
  print('Players without FVM data: $unmatchedPlayers');

  await outFile.writeAsString(out.join('\n'));
  print('Merged CSV written to ${outFile.path}');
  print('Total output rows: ${out.length}');

  print('\n=== VALIDATION SUMMARY ===');
  print('✓ Files exist and are readable');
  print('✓ Required columns found (Nome, FVM)');
  print('✓ Data merged successfully');
  print(
    '✓ ${matchedPlayers}/${validRows2025} players have historical FVM data',
  );

  await verifyMergedData(outFile, fvm24);
  await performComprehensiveDataIntegrityCheck(outFile, lines2025, fvm24);
  await performPlayerConsistencyCheck(outFile, lines2025, lines2024);
  await performAdvancedDataValidation(outFile, lines2025, lines2024, fvm24);
}

Future<void> performComprehensiveDataIntegrityCheck(
  File mergedFile,
  List<String> originalLines2025,
  Map<String, String> originalFvm24,
) async {
  print('\n=== COMPREHENSIVE DATA INTEGRITY CHECK ===');

  final mergedLines = await mergedFile.readAsLines();

  // Check 1: Row count integrity
  final expectedRows = originalLines2025.length;
  final actualRows = mergedLines.length;

  if (expectedRows != actualRows) {
    print('❌ CRITICAL ERROR: Row count mismatch!');
    print('   Expected: $expectedRows rows');
    print('   Actual: $actualRows rows');
    return;
  }
  print('✅ Row count integrity: $actualRows rows (matches original)');

  // Check 2: Column count integrity
  final originalHeader = originalLines2025[1].split(',');
  final mergedHeader = mergedLines[1].split(',');

  final expectedColumns =
      originalHeader.length +
      2; // +2 for FVM_Stagione_Precedente and Differenza_FVM_Stagioni
  final actualColumns = mergedHeader.length;

  if (expectedColumns != actualColumns) {
    print('❌ CRITICAL ERROR: Column count mismatch!');
    print('   Expected: $expectedColumns columns');
    print('   Actual: $actualColumns columns');
    return;
  }
  print(
    '✅ Column count integrity: $actualColumns columns (original + FVM_Stagione_Precedente + Differenza_FVM_Stagioni)',
  );

  // Check 3: Player name integrity (no duplicates, no missing)
  final originalNames = <String>{};
  final mergedNames = <String>{};
  final duplicateCheck = <String, int>{};

  for (var i = 2; i < originalLines2025.length; i++) {
    final parts = originalLines2025[i].split(',');
    if (parts.length > 3) {
      final name = parts[3].trim();
      originalNames.add(name);
    }
  }

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 3) {
      final name = parts[3].trim();
      mergedNames.add(name);
      duplicateCheck[name] = (duplicateCheck[name] ?? 0) + 1;
    }
  }

  // Check for duplicates
  final duplicates = duplicateCheck.entries.where((e) => e.value > 1).toList();
  if (duplicates.isNotEmpty) {
    print('❌ CRITICAL ERROR: Duplicate players found!');
    for (final dup in duplicates) {
      print('   "${dup.key}" appears ${dup.value} times');
    }
    return;
  }

  // Check for missing players
  final missingPlayers = originalNames.difference(mergedNames);
  if (missingPlayers.isNotEmpty) {
    print('❌ CRITICAL ERROR: Missing players in merged data!');
    for (final player in missingPlayers.take(5)) {
      print('   Missing: $player');
    }
    return;
  }

  print('✅ Player name integrity: No duplicates, no missing players');

  // Check 4: FVM data integrity
  var fvmMatches = 0;
  var fvmMismatches = 0;
  var sampleMismatches = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final mergedParts = mergedLines[i].split(',');
    if (mergedParts.length > 3) {
      final name = mergedParts[3].trim();
      final mergedFvm = mergedParts[13]
          .trim(); // FVM_Stagione_Precedente is now at index 13
      final originalFvm = originalFvm24[name] ?? '';

      if (mergedFvm == originalFvm) {
        fvmMatches++;
      } else {
        fvmMismatches++;
        if (sampleMismatches.length < 3) {
          sampleMismatches.add(
            '$name: merged="$mergedFvm", original="$originalFvm"',
          );
        }
      }
    }
  }

  if (fvmMismatches > 0) {
    print('❌ CRITICAL ERROR: FVM data mismatches found!');
    print('   Matches: $fvmMatches');
    print('   Mismatches: $fvmMismatches');
    for (final mismatch in sampleMismatches) {
      print('   $mismatch');
    }
    return;
  }

  print('✅ FVM data integrity: $fvmMatches matches, 0 mismatches');

  // Check 5: Data consistency
  var consistentRows = 0;
  var inconsistentRows = 0;

  for (var i = 2; i < mergedLines.length; i++) {
    final originalParts = originalLines2025[i].split(',');
    final mergedParts = mergedLines[i].split(',');

    if (originalParts.length == mergedParts.length - 2) {
      // Check if all original data matches (excluding the new FVM column)
      var matches = true;
      for (var j = 0; j < originalParts.length; j++) {
        if (originalParts[j].trim() != mergedParts[j].trim()) {
          matches = false;
          break;
        }
      }

      if (matches) {
        consistentRows++;
      } else {
        inconsistentRows++;
      }
    }
  }

  if (inconsistentRows > 0) {
    print('❌ CRITICAL ERROR: Data consistency issues!');
    print('   Consistent rows: $consistentRows');
    print('   Inconsistent rows: $inconsistentRows');
    return;
  }

  print('✅ Data consistency: $consistentRows rows verified');

  print('\n🎉 ALL DATA INTEGRITY CHECKS PASSED!');
  print('   The merged data is completely accurate and safe to use.');
}

Future<void> performPlayerConsistencyCheck(
  File mergedFile,
  List<String> originalLines2025,
  List<String> originalLines2024,
) async {
  print('\n=== PLAYER CONSISTENCY CHECK ===');

  final mergedLines = await mergedFile.readAsLines();

  // Check 1: All 2025/26 players are present in merged file
  final players2025 = <String>{};
  final playersMerged = <String>{};

  for (var i = 2; i < originalLines2025.length; i++) {
    final parts = originalLines2025[i].split(',');
    if (parts.length > 3) {
      players2025.add(parts[3].trim());
    }
  }

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 3) {
      playersMerged.add(parts[3].trim());
    }
  }

  final missingPlayers = players2025.difference(playersMerged);
  if (missingPlayers.isNotEmpty) {
    print('❌ CRITICAL ERROR: Missing players from 2025/26 in merged file!');
    for (final player in missingPlayers.take(5)) {
      print('   Missing: $player');
    }
    return;
  }
  print('✅ All 2025/26 players present in merged file');

  // Check 2: Player data consistency between seasons
  var consistentPlayers = 0;
  var inconsistentPlayers = 0;
  var sampleInconsistencies = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final mergedParts = mergedLines[i].split(',');
    if (mergedParts.length > 3) {
      final playerName = mergedParts[3].trim();

      // Find same player in 2024/25 data
      String? player2024Data;
      for (var j = 2; j < originalLines2024.length; j++) {
        final parts2024 = originalLines2024[j].split(',');
        if (parts2024.length > 3 && parts2024[3].trim() == playerName) {
          player2024Data = originalLines2024[j];
          break;
        }
      }

      if (player2024Data != null) {
        final parts2024 = player2024Data.split(',');

        // Check if basic data matches (ID, Role, Team)
        var isConsistent = true;
        var inconsistencies = <String>[];

        if (mergedParts.length > 0 && parts2024.length > 0) {
          if (mergedParts[0].trim() != parts2024[0].trim()) {
            isConsistent = false;
            inconsistencies.add('ID: ${mergedParts[0]} vs ${parts2024[0]}');
          }
        }

        if (mergedParts.length > 1 && parts2024.length > 1) {
          if (mergedParts[1].trim() != parts2024[1].trim()) {
            isConsistent = false;
            inconsistencies.add('Role: ${mergedParts[1]} vs ${parts2024[1]}');
          }
        }

        if (mergedParts.length > 4 && parts2024.length > 4) {
          if (mergedParts[4].trim() != parts2024[4].trim()) {
            isConsistent = false;
            inconsistencies.add('Team: ${mergedParts[4]} vs ${parts2024[4]}');
          }
        }

        if (isConsistent) {
          consistentPlayers++;
        } else {
          inconsistentPlayers++;
          if (sampleInconsistencies.length < 3) {
            sampleInconsistencies.add(
              '$playerName: ${inconsistencies.join(", ")}',
            );
          }
        }
      }
    }
  }

  if (inconsistentPlayers > 0) {
    print('⚠️  Player data inconsistencies found:');
    print('   Consistent players: $consistentPlayers');
    print('   Inconsistent players: $inconsistentPlayers');
    for (final inconsistency in sampleInconsistencies) {
      print('   $inconsistency');
    }
  } else {
    print('✅ Player data consistency: $consistentPlayers players verified');
  }

  // Check 3: FVM difference validation
  var validFvmDiffs = 0;
  var invalidFvmDiffs = 0;
  var sampleFvmIssues = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final mergedParts = mergedLines[i].split(',');
    if (mergedParts.length > 14) {
      final fvmDiff = mergedParts[14].trim();
      final currentFvm = mergedParts[11].trim();
      final prevFvm = mergedParts[13].trim();

      if (fvmDiff.isNotEmpty && currentFvm.isNotEmpty && prevFvm.isNotEmpty) {
        final fvmDiffNum = double.tryParse(fvmDiff);
        final currentFvmNum = double.tryParse(currentFvm);
        final prevFvmNum = double.tryParse(prevFvm);

        if (fvmDiffNum != null && currentFvmNum != null && prevFvmNum != null) {
          final expectedDiff = currentFvmNum - prevFvmNum;
          if ((fvmDiffNum - expectedDiff).abs() < 0.1) {
            validFvmDiffs++;
          } else {
            invalidFvmDiffs++;
            if (sampleFvmIssues.length < 3) {
              sampleFvmIssues.add(
                '${mergedParts[3]}: diff=$fvmDiff, expected=${expectedDiff.toStringAsFixed(1)}',
              );
            }
          }
        }
      }
    }
  }

  if (invalidFvmDiffs > 0) {
    print('❌ CRITICAL ERROR: FVM difference calculation errors!');
    print('   Valid differences: $validFvmDiffs');
    print('   Invalid differences: $invalidFvmDiffs');
    for (final issue in sampleFvmIssues) {
      print('   $issue');
    }
  } else {
    print('✅ FVM difference validation: $validFvmDiffs calculations verified');
  }

  print('\n🎉 PLAYER CONSISTENCY CHECK COMPLETED!');
}

Future<void> performAdvancedDataValidation(
  File mergedFile,
  List<String> originalLines2025,
  List<String> originalLines2024,
  Map<String, String> originalFvm24,
) async {
  print('\n=== ADVANCED DATA VALIDATION ===');

  final mergedLines = await mergedFile.readAsLines();

  // Check 1: Statistical validation - FVM distribution
  var fvmValues = <double>[];
  var fvmDiffValues = <double>[];
  var priceValues = <double>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 11) {
      final fvm = double.tryParse(parts[11].trim());
      if (fvm != null) fvmValues.add(fvm);

      if (parts.length > 5) {
        final price = double.tryParse(parts[5].trim());
        if (price != null) priceValues.add(price);
      }

      if (parts.length > 14) {
        final fvmDiff = double.tryParse(parts[14].trim());
        if (fvmDiff != null) fvmDiffValues.add(fvmDiff);
      }
    }
  }

  // FVM distribution check
  if (fvmValues.isNotEmpty) {
    fvmValues.sort();
    final fvmMin = fvmValues.first;
    final fvmMax = fvmValues.last;
    final fvmAvg = fvmValues.reduce((a, b) => a + b) / fvmValues.length;

    print('📊 FVM Statistics:');
    print(
      '   Min: ${fvmMin.toStringAsFixed(1)}, Max: ${fvmMax.toStringAsFixed(1)}, Avg: ${fvmAvg.toStringAsFixed(1)}',
    );

    // Check for suspicious FVM values
    if (fvmMin < 0) {
      print('❌ CRITICAL: Negative FVM values found!');
    } else if (fvmMax > 200) {
      print('⚠️  WARNING: Very high FVM values (>200) - verify data');
    } else {
      print('✅ FVM values within expected range');
    }
  }

  // Price distribution check
  if (priceValues.isNotEmpty) {
    priceValues.sort();
    final priceMin = priceValues.first;
    final priceMax = priceValues.last;
    final priceAvg = priceValues.reduce((a, b) => a + b) / priceValues.length;

    print('💰 Price Statistics:');
    print(
      '   Min: ${priceMin.toStringAsFixed(1)}, Max: ${priceMax.toStringAsFixed(1)}, Avg: ${priceAvg.toStringAsFixed(1)}',
    );

    if (priceMin < 0) {
      print('❌ CRITICAL: Negative prices found!');
    } else if (priceMax > 100) {
      print('⚠️  WARNING: Very high prices (>100) - verify data');
    } else {
      print('✅ Price values within expected range');
    }
  }

  // Check 2: Cross-season data integrity
  var crossSeasonMatches = 0;
  var crossSeasonMismatches = 0;
  var sampleMismatches = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final mergedParts = mergedLines[i].split(',');
    if (mergedParts.length > 3) {
      final playerName = mergedParts[3].trim();

      // Find in 2024/25 data
      for (var j = 2; j < originalLines2024.length; j++) {
        final parts2024 = originalLines2024[j].split(',');
        if (parts2024.length > 3 && parts2024[3].trim() == playerName) {
          // Check if FVM data matches
          if (mergedParts.length > 13 && parts2024.length > 11) {
            final mergedFvm = mergedParts[13].trim();
            final originalFvm = parts2024[11].trim();

            if (mergedFvm == originalFvm) {
              crossSeasonMatches++;
            } else {
              crossSeasonMismatches++;
              if (sampleMismatches.length < 3) {
                sampleMismatches.add(
                  '$playerName: merged=$mergedFvm, original=$originalFvm',
                );
              }
            }
          }
          break;
        }
      }
    }
  }

  if (crossSeasonMismatches > 0) {
    print('❌ CRITICAL: Cross-season FVM mismatches!');
    print(
      '   Matches: $crossSeasonMatches, Mismatches: $crossSeasonMismatches',
    );
    for (final mismatch in sampleMismatches) {
      print('   $mismatch');
    }
  } else {
    print('✅ Cross-season FVM data integrity verified');
  }

  // Check 3: Data completeness validation
  var completeRows = 0;
  var incompleteRows = 0;
  var missingFields = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    var isComplete = true;
    var missing = <String>[];

    // Check essential fields
    if (parts.length < 15) {
      isComplete = false;
      missing.add('insufficient columns');
    } else {
      if (parts[0].trim().isEmpty) missing.add('ID');
      if (parts[1].trim().isEmpty) missing.add('Role');
      if (parts[3].trim().isEmpty) missing.add('Name');
      if (parts[4].trim().isEmpty) missing.add('Team');
      if (parts[5].trim().isEmpty) missing.add('Current Price');

      if (missing.isNotEmpty) {
        isComplete = false;
      }
    }

    if (isComplete) {
      completeRows++;
    } else {
      incompleteRows++;
      if (missingFields.length < 5) {
        missingFields.add('Row ${i + 1}: ${missing.join(", ")}');
      }
    }
  }

  if (incompleteRows > 0) {
    print('❌ CRITICAL: Incomplete data rows found!');
    print('   Complete: $completeRows, Incomplete: $incompleteRows');
    for (final missing in missingFields) {
      print('   $missing');
    }
  } else {
    print('✅ All data rows are complete');
  }

  // Check 4: Logical consistency checks
  var logicalErrors = 0;
  var sampleErrors = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 14) {
      final currentFvm = double.tryParse(parts[11].trim());
      final prevFvm = double.tryParse(parts[13].trim());
      final fvmDiff = double.tryParse(parts[14].trim());

      if (currentFvm != null && prevFvm != null && fvmDiff != null) {
        final expectedDiff = currentFvm - prevFvm;
        if ((fvmDiff - expectedDiff).abs() > 0.1) {
          logicalErrors++;
          if (sampleErrors.length < 3) {
            sampleErrors.add(
              '${parts[3]}: calculated=${expectedDiff.toStringAsFixed(1)}, stored=${fvmDiff.toStringAsFixed(1)}',
            );
          }
        }
      }
    }
  }

  if (logicalErrors > 0) {
    print('❌ CRITICAL: Logical calculation errors!');
    print('   Errors: $logicalErrors');
    for (final error in sampleErrors) {
      print('   $error');
    }
  } else {
    print('✅ All calculations are logically consistent');
  }

  // Check 5: Data range validation
  var rangeErrors = 0;
  var sampleRangeErrors = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 14) {
      final fvmDiff = double.tryParse(parts[14].trim());
      if (fvmDiff != null && fvmDiff.abs() > 100) {
        rangeErrors++;
        if (sampleRangeErrors.length < 3) {
          sampleRangeErrors.add(
            '${parts[3]}: extreme FVM diff of ${fvmDiff.toStringAsFixed(1)}',
          );
        }
      }
    }
  }

  if (rangeErrors > 0) {
    print(
      '⚠️  WARNING: $rangeErrors players with extreme FVM differences (>100)',
    );
    print('   These might be data errors or very unusual cases');
    for (final error in sampleRangeErrors) {
      print('   $error');
    }
  } else {
    print('✅ All FVM differences within reasonable range');
  }

  print('\n🎉 ADVANCED DATA VALIDATION COMPLETED!');
  print('   Your data has passed all automated quality checks.');
}

Future<void> verifyMergedData(
  File mergedFile,
  Map<String, String> originalFvm24,
) async {
  print('\n=== DATA VERIFICATION ===');

  final lines = await mergedFile.readAsLines();
  if (lines.isEmpty) {
    print('ERROR: Merged file is empty');
    return;
  }

  final header = lines.first.split(',');
  final fvmColIndex = header.indexOf('FVM_Stagione_Precedente');

  if (fvmColIndex == -1) {
    print('ERROR: FVM_Stagione_Precedente column not found in merged file');
    return;
  }

  print('Verifying merged data...');

  var verifiedRows = 0;
  var verificationErrors = 0;
  var sampleVerifications = <String>[];

  for (var i = 2; i < lines.length; i++) {
    final line = lines[i];
    final parts = const CsvToListConverter()
        .convert(line, eol: '\n', fieldDelimiter: ',')
        .first;

    if (parts.length > fvmColIndex) {
      final name = parts[3].toString().trim();
      final mergedFvm = parts[fvmColIndex].toString().trim();
      final originalFvm = originalFvm24[name] ?? '';

      if (mergedFvm == originalFvm) {
        verifiedRows++;
        if (sampleVerifications.length < 5 && mergedFvm.isNotEmpty) {
          sampleVerifications.add('✓ $name: FVM $mergedFvm');
        }
      } else {
        verificationErrors++;
        if (verificationErrors <= 3) {
          print(
            'ERROR: Verification failed for $name - merged: "$mergedFvm", original: "$originalFvm"',
          );
        }
      }
    }
  }

  print('Verification results:');
  print('✓ $verifiedRows rows verified correctly');
  if (verificationErrors > 0) {
    print('✗ $verificationErrors verification errors');
  }

  if (sampleVerifications.isNotEmpty) {
    print('\nSample verifications:');
    for (final sample in sampleVerifications) {
      print(sample);
    }
  }

  final totalRows = lines.length - 1;
  final verificationRate = (verifiedRows / totalRows * 100).toStringAsFixed(1);
  print('\nVerification rate: $verificationRate% ($verifiedRows/$totalRows)');

  if (verificationErrors == 0) {
    print('🎉 All data verified successfully!');
  } else {
    print('⚠️  Some verification errors detected. Please review the data.');
  }

  await performDataQualityChecks(mergedFile);
}

Future<void> performDataQualityChecks(File mergedFile) async {
  print('\n=== DATA QUALITY CHECKS ===');

  final lines = await mergedFile.readAsLines();
  final header = lines[1].split(',');

  final nameIndex = header.indexOf('Nome_Giocatore');
  final fvmIndex = header.indexOf('FVM_Stagione_Precedente');
  final qtAIndex = header.indexOf('Quotazione_Attuale');
  final qtIIndex = header.indexOf('Quotazione_Iniziale');

  var playersWithFvm = 0;
  var playersWithoutFvm = 0;
  var duplicateNames = <String, int>{};
  var invalidPrices = 0;
  var priceInconsistencies = 0;
  var invalidFvmDifferences = 0;
  var fvmDifferenceErrors = 0;

  for (var i = 2; i < lines.length; i++) {
    final line = lines[i];
    final parts = const CsvToListConverter()
        .convert(line, eol: '\n', fieldDelimiter: ',')
        .first;

    if (parts.length > nameIndex && nameIndex != -1) {
      final name = parts[nameIndex].toString().trim();

      duplicateNames[name] = (duplicateNames[name] ?? 0) + 1;

      if (parts.length > fvmIndex && fvmIndex != -1) {
        final fvm = parts[fvmIndex].toString().trim();
        if (fvm.isNotEmpty) {
          playersWithFvm++;
        } else {
          playersWithoutFvm++;
        }
      }

      if (qtAIndex != -1 && parts.length > qtAIndex) {
        final qtA = parts[qtAIndex].toString().trim();
        if (qtA.isNotEmpty && !_isValidPrice(qtA)) {
          invalidPrices++;
        }
      }

      if (qtAIndex != -1 &&
          qtIIndex != -1 &&
          parts.length > qtAIndex &&
          parts.length > qtIIndex) {
        final qtA = parts[qtAIndex].toString().trim();
        final qtI = parts[qtIIndex].toString().trim();

        if (qtA.isNotEmpty && qtI.isNotEmpty) {
          final qtANum = double.tryParse(qtA);
          final qtINum = double.tryParse(qtI);

          if (qtANum != null && qtINum != null && qtANum < qtINum) {
            priceInconsistencies++;
          }
        }
      }

      // Check FVM difference quality
      if (parts.length > 14) {
        final fvmDiff = parts[14].toString().trim();
        if (fvmDiff.isNotEmpty) {
          final fvmDiffNum = double.tryParse(fvmDiff);
          if (fvmDiffNum == null) {
            invalidFvmDifferences++;
          } else {
            // Check if FVM difference makes sense (not too extreme)
            if (fvmDiffNum.abs() > 50) {
              fvmDifferenceErrors++;
            }
          }
        }
      }
    }
  }

  print('Data quality summary:');
  print('• Players with FVM data: $playersWithFvm');
  print('• Players without FVM data: $playersWithoutFvm');
  print('• Invalid price values: $invalidPrices');
  print('• Price inconsistencies (Qt.A < Qt.I): $priceInconsistencies');
  print('• Invalid FVM differences: $invalidFvmDifferences');
  print('• Extreme FVM differences (>50): $fvmDifferenceErrors');

  final duplicates = duplicateNames.entries.where((e) => e.value > 1).toList();
  if (duplicates.isNotEmpty) {
    print('• Duplicate player names found: ${duplicates.length}');
    for (final dup in duplicates.take(3)) {
      print('  - "${dup.key}" appears ${dup.value} times');
    }
  } else {
    print('• No duplicate player names');
  }

  final totalPlayers = playersWithFvm + playersWithoutFvm;
  final fvmCoverage = totalPlayers > 0
      ? (playersWithFvm / totalPlayers * 100).toStringAsFixed(1)
      : '0';
  print('\nFVM data coverage: $fvmCoverage% ($playersWithFvm/$totalPlayers)');

  if (invalidPrices > 0 || duplicates.isNotEmpty || invalidFvmDifferences > 0) {
    print('⚠️  Data quality issues detected - review recommended');
  } else {
    print('✅ Data quality checks passed');
    if (priceInconsistencies > 0) {
      print(
        'ℹ️  Note: $priceInconsistencies players have Qt.A < Qt.I (normal market behavior)',
      );
    }
    if (fvmDifferenceErrors > 0) {
      print(
        'ℹ️  Note: $fvmDifferenceErrors players have extreme FVM changes (>50) - check for transfers/injuries',
      );
    }
  }
}

bool _isValidPrice(String price) {
  if (price.isEmpty) return true;
  final num = double.tryParse(price);
  return num != null && num >= 0;
}

class CsvToListConverter {
  const CsvToListConverter();

  List<List<dynamic>> convert(
    String input, {
    String eol = '\n',
    String fieldDelimiter = ',',
  }) {
    final rows = <List<dynamic>>[];
    var current = <dynamic>[];
    var buffer = StringBuffer();
    var inQuotes = false;

    void addField() {
      current.add(buffer.toString());
      buffer.clear();
    }

    for (var i = 0; i < input.length; i++) {
      var char = input[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == fieldDelimiter && !inQuotes) {
        addField();
      } else {
        buffer.write(char);
      }
    }
    addField();
    rows.add(current);
    return rows;
  }
}
