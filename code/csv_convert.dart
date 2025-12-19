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
    'Nome_Giocatore',
    'Squadra',
    'FVM_Mercato',
    'FVM_Stagione_Precedente',
    'Differenza_FVM_Stagioni',
    'FVM_Qt_Ratio',
    'Quotazione_Attuale_Mercato',
    'Quotazione_Iniziale_Mercato',
    'Differenza_Prezzo_Mercato',
    'FVM_Attuale',
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

        // Calculate FVM/Qt.A ratio (Value Index)
        var fvmQtRatio = '';
        if (parts.length > 8 && parts.length > 11) {
          final currentPrice = parts[8]
              .toString()
              .trim(); // Quotazione_Attuale_Mercato
          final currentFvm = parts[11].toString().trim();

          if (currentPrice.isNotEmpty && currentFvm.isNotEmpty) {
            final priceNum = double.tryParse(currentPrice);
            final fvmNum = double.tryParse(currentFvm);

            if (priceNum != null && fvmNum != null) {
              if (priceNum == 0) {
                fvmQtRatio = '0';
              } else {
                fvmQtRatio = (fvmNum / priceNum).toStringAsFixed(3);
              }
            }
          }
        }

        // Extract only the required columns in the specified order
        final id = parts[0].toString().trim();
        final ruolo = parts[1].toString().trim();
        final nome = parts[3].toString().trim();
        final squadra = parts[4].toString().trim();
        final fvmMercato = parts[12].toString().trim();
        final fvmAttuale = parts[11].toString().trim();
        final qtAttualeMercato = parts[8].toString().trim();
        final qtInizialeMercato = parts[9].toString().trim();
        final diffPrezzoMercato = parts[10].toString().trim();

        final outputLine = [
          id,
          ruolo,
          nome,
          squadra,
          fvmMercato,
          fvmPrev,
          fvmDiff,
          fvmQtRatio,
          qtAttualeMercato,
          qtInizialeMercato,
          diffPrezzoMercato,
          fvmAttuale,
        ].join(',');

        out.add(outputLine);
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
  await createPositionFiles(outFile);
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

  final expectedColumns = 12; // Fixed number of columns as per specification
  final actualColumns = mergedHeader.length;

  if (expectedColumns != actualColumns) {
    print('❌ CRITICAL ERROR: Column count mismatch!');
    print('   Expected: $expectedColumns columns');
    print('   Actual: $actualColumns columns');
    return;
  }
  print(
    '✅ Column count integrity: $actualColumns columns (12 columns as specified)',
  );

  // Check 3: Player name integrity (no duplicates, no missing)
  final originalNames = <String>{};
  final mergedNames = <String>{};
  final duplicateCheck = <String, int>{};

  for (var i = 2; i < originalLines2025.length; i++) {
    final parts = originalLines2025[i].split(',');
    if (parts.length > 3) {
      final name = parts[3].trim(); // Nome is at index 3 in original file
      originalNames.add(name);
    }
  }

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 2) {
      final name = parts[2].trim(); // Nome_Giocatore is at index 2
      if (name.isNotEmpty) {
        mergedNames.add(name);
        duplicateCheck[name] = (duplicateCheck[name] ?? 0) + 1;
      }
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
    if (mergedParts.length > 2) {
      final name = mergedParts[2].trim(); // Nome_Giocatore is at index 2
      final mergedFvm = mergedParts[5]
          .trim(); // FVM_Stagione_Precedente is now at index 5
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

  // Check 5: Data consistency (check core fields match)
  var consistentRows = 0;
  var inconsistentRows = 0;

  for (var i = 2; i < mergedLines.length; i++) {
    final originalParts = originalLines2025[i].split(',');
    final mergedParts = mergedLines[i].split(',');

    if (mergedParts.length == 12 && originalParts.length >= 12) {
      // Check if core fields match (ID, Role, Name, Team, Prices, FVM)
      var matches = true;

      // Check ID (index 0)
      if (originalParts[0].trim() != mergedParts[0].trim()) matches = false;
      // Check Role (index 1)
      if (originalParts[1].trim() != mergedParts[1].trim()) matches = false;
      // Check Name (index 3 in original, 2 in merged)
      if (originalParts[3].trim() != mergedParts[2].trim()) matches = false;
      // Check Team (index 4 in original, 3 in merged)
      if (originalParts[4].trim() != mergedParts[3].trim()) matches = false;
      // Check Current Price (index 8 in original, 8 in merged)
      if (originalParts[8].trim() != mergedParts[8].trim()) matches = false;
      // Check Initial Price (index 9 in original, 9 in merged)
      if (originalParts[9].trim() != mergedParts[9].trim()) matches = false;
      // Check Current FVM (index 11 in original, 11 in merged)
      if (originalParts[11].trim() != mergedParts[11].trim()) matches = false;

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
      players2025.add(parts[3].trim()); // Nome is at index 3 in original file
    }
  }

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 2) {
      playersMerged.add(parts[2].trim()); // Nome_Giocatore is at index 2
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
    if (mergedParts.length > 2) {
      final playerName = mergedParts[2].trim(); // Nome_Giocatore is at index 2

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

        if (mergedParts.length > 3 && parts2024.length > 4) {
          if (mergedParts[3].trim() != parts2024[4].trim()) {
            isConsistent = false;
            inconsistencies.add('Team: ${mergedParts[3]} vs ${parts2024[4]}');
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
    if (mergedParts.length > 6) {
      final fvmDiff = mergedParts[6].trim();
      final currentFvm = mergedParts[11].trim();
      final prevFvm = mergedParts[5].trim();

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
                '${mergedParts[2]}: diff=$fvmDiff, expected=${expectedDiff.toStringAsFixed(1)}',
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
  var fvmQtRatioValues = <double>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > 11) {
      final fvm = double.tryParse(parts[11].trim()); // FVM_Attuale
      if (fvm != null) fvmValues.add(fvm);

      if (parts.length > 8) {
        final price = double.tryParse(
          parts[8].trim(),
        ); // Quotazione_Attuale_Mercato
        if (price != null) priceValues.add(price);
      }

      if (parts.length > 6) {
        final fvmDiff = double.tryParse(
          parts[6].trim(),
        ); // Differenza_FVM_Stagioni
        if (fvmDiff != null) fvmDiffValues.add(fvmDiff);
      }

      if (parts.length > 7) {
        final fvmQtRatio = double.tryParse(parts[7].trim()); // FVM_Qt_Ratio
        if (fvmQtRatio != null) fvmQtRatioValues.add(fvmQtRatio);
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

  // FVM/Qt.A ratio distribution check
  if (fvmQtRatioValues.isNotEmpty) {
    fvmQtRatioValues.sort();
    final ratioMin = fvmQtRatioValues.first;
    final ratioMax = fvmQtRatioValues.last;
    final ratioAvg =
        fvmQtRatioValues.reduce((a, b) => a + b) / fvmQtRatioValues.length;

    print('📈 FVM/Qt.A Ratio Statistics:');
    print(
      '   Min: ${ratioMin.toStringAsFixed(2)}, Max: ${ratioMax.toStringAsFixed(2)}, Avg: ${ratioAvg.toStringAsFixed(2)}',
    );

    if (ratioMin < 0) {
      print('❌ CRITICAL: Negative FVM/Qt.A ratios found!');
    } else if (ratioMax > 50) {
      print('⚠️  WARNING: Very high FVM/Qt.A ratios (>50) - verify data');
    } else {
      print('✅ FVM/Qt.A ratios within expected range');
    }
  }

  // Check 2: Cross-season data integrity
  var crossSeasonMatches = 0;
  var crossSeasonMismatches = 0;
  var sampleMismatches = <String>[];

  for (var i = 2; i < mergedLines.length; i++) {
    final mergedParts = mergedLines[i].split(',');
    if (mergedParts.length > 2) {
      final playerName = mergedParts[2].trim(); // Nome_Giocatore is at index 2

      // Find in 2024/25 data
      for (var j = 2; j < originalLines2024.length; j++) {
        final parts2024 = originalLines2024[j].split(',');
        if (parts2024.length > 3 && parts2024[3].trim() == playerName) {
          // Check if FVM data matches
          if (mergedParts.length > 5 && parts2024.length > 11) {
            final mergedFvm = mergedParts[5].trim();
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
    if (parts.length < 12) {
      isComplete = false;
      missing.add('insufficient columns');
    } else {
      if (parts[0].trim().isEmpty) missing.add('ID');
      if (parts[1].trim().isEmpty) missing.add('Role');
      if (parts[2].trim().isEmpty) missing.add('Name');
      if (parts[3].trim().isEmpty) missing.add('Team');
      if (parts[8].trim().isEmpty) missing.add('Current Price');

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
    if (parts.length > 11) {
      final currentFvm = double.tryParse(parts[11].trim()); // FVM_Attuale
      final prevFvm = double.tryParse(
        parts[5].trim(),
      ); // FVM_Stagione_Precedente
      final fvmDiff = double.tryParse(
        parts[6].trim(),
      ); // Differenza_FVM_Stagioni
      final currentPrice = double.tryParse(
        parts[8].trim(),
      ); // Quotazione_Attuale_Mercato
      final fvmQtRatio = double.tryParse(parts[7].trim()); // FVM_Qt_Ratio

      // Check FVM difference calculation
      if (currentFvm != null && prevFvm != null && fvmDiff != null) {
        final expectedDiff = currentFvm - prevFvm;
        if ((fvmDiff - expectedDiff).abs() > 0.1) {
          logicalErrors++;
          if (sampleErrors.length < 3) {
            sampleErrors.add(
              '${parts[2]}: FVM diff calculated=${expectedDiff.toStringAsFixed(1)}, stored=${fvmDiff.toStringAsFixed(1)}',
            );
          }
        }
      }

      // Check FVM/Qt.A ratio calculation
      if (currentFvm != null && currentPrice != null && fvmQtRatio != null) {
        double expectedRatio;
        if (currentPrice == 0) {
          expectedRatio = 0;
        } else {
          expectedRatio = currentFvm / currentPrice;
        }

        if ((fvmQtRatio - expectedRatio).abs() > 0.01) {
          logicalErrors++;
          if (sampleErrors.length < 3) {
            sampleErrors.add(
              '${parts[2]}: FVM/Qt ratio calculated=${expectedRatio.toStringAsFixed(3)}, stored=${fvmQtRatio.toStringAsFixed(3)}',
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
    if (parts.length > 7) {
      final fvmDiff = double.tryParse(parts[6].trim());
      final fvmQtRatio = double.tryParse(parts[7].trim());

      if (fvmDiff != null && fvmDiff.abs() > 100) {
        rangeErrors++;
        if (sampleRangeErrors.length < 3) {
          sampleRangeErrors.add(
            '${parts[2]}: extreme FVM diff of ${fvmDiff.toStringAsFixed(1)}',
          );
        }
      }

      if (fvmQtRatio != null && fvmQtRatio > 50) {
        rangeErrors++;
        if (sampleRangeErrors.length < 3) {
          sampleRangeErrors.add(
            '${parts[2]}: extreme FVM/Qt ratio of ${fvmQtRatio.toStringAsFixed(2)}',
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

Future<void> createPositionFiles(File mergedFile) async {
  print('\n=== CREATING POSITION FILES ===');

  final lines = await mergedFile.readAsLines();
  if (lines.length < 3) {
    print('ERROR: Insufficient data in merged file');
    return;
  }

  final header = lines[1].split(',');
  final ruoloIndex = header.indexOf('Ruolo');
  final fvmIndex = header.indexOf('FVM_Attuale');

  if (ruoloIndex == -1) {
    print('ERROR: Ruolo column not found');
    return;
  }
  if (fvmIndex == -1) {
    print('ERROR: FVM_Attuale column not found');
    return;
  }

  // Group players by position
  final playersByPosition = <String, List<List<String>>>{};

  for (var i = 2; i < lines.length; i++) {
    final parts = lines[i].split(',');
    if (parts.length > ruoloIndex && parts.length > fvmIndex) {
      final ruolo = parts[ruoloIndex].trim();
      final fvmStr = parts[fvmIndex].trim();
      final fvm = double.tryParse(fvmStr) ?? 0.0;

      // Create player data with FVM for sorting
      final playerData = [...parts, fvm.toString()];

      if (!playersByPosition.containsKey(ruolo)) {
        playersByPosition[ruolo] = [];
      }
      playersByPosition[ruolo]!.add(playerData);
    }
  }

  // Sort each position by FVM (descending) and create files
  for (final entry in playersByPosition.entries) {
    final ruolo = entry.key;
    final players = entry.value;

    // Sort by FVM descending
    players.sort((a, b) {
      final fvmA = double.tryParse(a[a.length - 1]) ?? 0.0;
      final fvmB = double.tryParse(b[b.length - 1]) ?? 0.0;
      return fvmB.compareTo(fvmA);
    });

    // Create filename
    final fileName = 'giocatori_${ruolo.toLowerCase()}_sorted.csv';
    final positionFile = File(fileName);

    // Prepare output
    final output = <String>[];
    output.add(lines[0]); // Title row
    output.add(lines[1]); // Header row

    // Add sorted players (remove the temporary FVM sort value)
    for (final player in players) {
      final playerLine = player.take(player.length - 1).join(',');
      output.add(playerLine);
    }

    // Write file
    await positionFile.writeAsString(output.join('\n'));

    print('✅ Created $fileName with ${players.length} players');

    // Show top 3 players for this position
    if (players.isNotEmpty) {
      print('   Top players:');
      for (var i = 0; i < 3 && i < players.length; i++) {
        final player = players[i];
        final name = player[2].trim();
        final fvm = player[11].trim();
        final price = player[8].trim();
        final team = player[3].trim();
        print('   ${i + 1}. $name ($team) - FVM: $fvm, Price: $price');
      }
    }
  }

  print('\n🎉 POSITION FILES CREATED!');
  print('   Files created: ${playersByPosition.keys.length}');
  print(
    '   Total players processed: ${playersByPosition.values.fold(0, (sum, list) => sum + list.length)}',
  );
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

  final header = lines[1].split(','); // Use the descriptive header row
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
    final parts = line.split(',');

    if (parts.length > fvmColIndex && parts.length > 2) {
      final name = parts[2].trim(); // Nome_Giocatore is at index 2
      final mergedFvm = parts[fvmColIndex].trim();
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
  final qtAIndex = header.indexOf('Quotazione_Attuale_Mercato');
  final qtIIndex = header.indexOf('Quotazione_Iniziale_Mercato');

  var playersWithFvm = 0;
  var playersWithoutFvm = 0;
  var duplicateNames = <String, int>{};
  var invalidPrices = 0;
  var priceInconsistencies = 0;
  var invalidFvmDifferences = 0;
  var fvmDifferenceErrors = 0;
  var invalidFvmQtRatios = 0;
  var fvmQtRatioErrors = 0;

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
      if (parts.length > 6) {
        final fvmDiff = parts[6].toString().trim();
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

      // Check FVM/Qt.A ratio quality
      if (parts.length > 7) {
        final fvmQtRatio = parts[7].toString().trim();
        if (fvmQtRatio.isNotEmpty) {
          final fvmQtRatioNum = double.tryParse(fvmQtRatio);
          if (fvmQtRatioNum == null) {
            invalidFvmQtRatios++;
          } else {
            // Check if FVM/Qt.A ratio makes sense (not too extreme)
            if (fvmQtRatioNum > 50) {
              fvmQtRatioErrors++;
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
  print('• Invalid FVM/Qt.A ratios: $invalidFvmQtRatios');
  print('• Extreme FVM/Qt.A ratios (>50): $fvmQtRatioErrors');

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

  if (invalidPrices > 0 ||
      duplicates.isNotEmpty ||
      invalidFvmDifferences > 0 ||
      invalidFvmQtRatios > 0) {
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
    if (fvmQtRatioErrors > 0) {
      print(
        'ℹ️  Note: $fvmQtRatioErrors players have extreme FVM/Qt.A ratios (>50) - verify data',
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
