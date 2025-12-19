import 'dart:io';

void main() async {
  final fantacalcioFile = File('merged_2025_26.csv');
  final fbrefFile = File('fbref_players_clean.csv');
  final outputFile = File('merged_2025_26_with_fbref.csv');

  print('Starting FBRef statistics merge...');

  if (!await fantacalcioFile.exists()) {
    print('ERROR: merged_2025_26.csv not found');
    return;
  }
  if (!await fbrefFile.exists()) {
    print('ERROR: fbref_players_clean.csv not found');
    return;
  }

  final fantacalcioLines = await fantacalcioFile.readAsLines();
  final fbrefLines = await fbrefFile.readAsLines();

  print('Fantacalcio file: ${fantacalcioLines.length} lines');
  print('FBRef file: ${fbrefLines.length} lines');

  if (fantacalcioLines.isEmpty || fbrefLines.isEmpty) {
    print('ERROR: One or both files are empty');
    return;
  }

  // Parse FBRef data into a map for quick lookup
  final fbrefData = <String, Map<String, String>>{};
  final fbrefHeader = fbrefLines[0].split(',');

  print('FBRef columns: ${fbrefHeader.length}');
  print('FBRef headers: ${fbrefHeader.take(10).join(", ")}...');

  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 2) {
      final playerName = parts[1].trim(); // Player column
      final squad = parts[4].trim(); // Squad column

      // Create a unique key combining name and squad
      final key = '$playerName|$squad';

      final playerData = <String, String>{};
      for (var j = 0; j < parts.length && j < fbrefHeader.length; j++) {
        playerData[fbrefHeader[j]] = parts[j].trim();
      }

      fbrefData[key] = playerData;
    }
  }

  print('Loaded ${fbrefData.length} FBRef player records');

  // Create new header with FBRef statistics
  final fantacalcioHeader = fantacalcioLines[1].split(',');

  // Define FBRef column mappings with clear names
  final fbrefColumnMappings = {
    'MP': 'Partite_Giocate',
    'Starts': 'Partite_Titolare',
    'Min': 'Minuti_Giocati',
    '90s': 'Partite_90_Minuti',
    'Gls': 'Gol_Totali',
    'Ast': 'Assist_Totali',
    'G+A': 'Gol_Plus_Assist',
    'G-PK': 'Gol_Senza_Rigori',
    'PK': 'Rigori_Realizzati',
    'PKatt': 'Rigori_Tentati',
    'CrdY': 'Cartellini_Gialli',
    'CrdR': 'Cartellini_Rossi',
    'xG': 'Expected_Goals',
    'npxG': 'Expected_Goals_Senza_Rigori',
    'xAG': 'Expected_Assist',
    'npxG+xAG': 'Expected_Goals_Plus_Assist',
    'PrgC': 'Progressioni_Con_Palla',
    'PrgP': 'Progressioni_Passaggi',
    'PrgR': 'Progressioni_Ricezioni',
  };

  // Create the new header
  final newHeader = <String>[];

  // Add existing Fantacalcio columns
  newHeader.addAll(fantacalcioHeader);

  // Add FBRef statistics columns
  for (final mapping in fbrefColumnMappings.entries) {
    newHeader.add(mapping.value);
  }

  print('New header will have ${newHeader.length} columns');

  // Process each Fantacalcio player
  final output = <String>[];
  output.add(fantacalcioLines[0]); // Title row
  output.add(newHeader.join(','));

  var matchedPlayers = 0;
  var unmatchedPlayers = 0;
  var sampleMatches = <String>[];
  var sampleUnmatches = <String>[];

  for (var i = 2; i < fantacalcioLines.length; i++) {
    final line = fantacalcioLines[i];
    final parts = line.split(',');

    if (parts.length >= 4) {
      final playerName = parts[2].trim(); // Nome_Giocatore
      final squad = parts[3].trim(); // Squadra

      // Try to find matching FBRef data
      final key = '$playerName|$squad';
      final fbrefPlayer = fbrefData[key];

      final newRow = <String>[];

      // Add existing Fantacalcio data
      newRow.addAll(parts);

      // Add FBRef statistics (empty if not found)
      for (final mapping in fbrefColumnMappings.entries) {
        final fbrefValue = fbrefPlayer?[mapping.key] ?? '';
        newRow.add(fbrefValue);
      }

      output.add(newRow.join(','));

      if (fbrefPlayer != null) {
        matchedPlayers++;
        if (sampleMatches.length < 5) {
          final mp = fbrefPlayer['MP'] ?? '0';
          final gls = fbrefPlayer['Gls'] ?? '0';
          final ast = fbrefPlayer['Ast'] ?? '0';
          sampleMatches.add(
            '✓ $playerName ($squad): MP=$mp, Gls=$gls, Ast=$ast',
          );
        }
      } else {
        unmatchedPlayers++;
        if (sampleUnmatches.length < 5) {
          sampleUnmatches.add('✗ $playerName ($squad)');
        }
      }
    }
  }

  // Write the merged file
  await outputFile.writeAsString(output.join('\n'));

  print('\n=== MERGE RESULTS ===');
  print('✅ Merged file created: ${outputFile.path}');
  print('Total players: ${matchedPlayers + unmatchedPlayers}');
  print('Players with FBRef data: $matchedPlayers');
  print('Players without FBRef data: $unmatchedPlayers');

  final matchRate =
      ((matchedPlayers / (matchedPlayers + unmatchedPlayers)) * 100)
          .toStringAsFixed(1);
  print('Match rate: $matchRate%');

  if (sampleMatches.isNotEmpty) {
    print('\nSample matches:');
    for (final match in sampleMatches) {
      print(match);
    }
  }

  if (sampleUnmatches.isNotEmpty) {
    print('\nSample unmatched:');
    for (final unmatch in sampleUnmatches) {
      print(unmatch);
    }
  }

  // Create updated position files
  await createUpdatedPositionFiles(outputFile, newHeader);

  print('\n🎉 FBRef statistics merge completed!');
}

Future<void> createUpdatedPositionFiles(
  File mergedFile,
  List<String> header,
) async {
  print('\n=== CREATING UPDATED POSITION FILES ===');

  final lines = await mergedFile.readAsLines();
  if (lines.length < 3) {
    print('ERROR: Insufficient data in merged file');
    return;
  }

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
    final fileName = 'giocatori_${ruolo.toLowerCase()}_with_fbref.csv';
    final positionFile = File(fileName);

    // Prepare output
    final output = <String>[];
    output.add(lines[0]); // Title row
    output.add(header.join(',')); // New header with FBRef stats

    // Add sorted players (remove the temporary FVM sort value)
    for (final player in players) {
      final playerLine = player.take(player.length - 1).join(',');
      output.add(playerLine);
    }

    // Write file
    await positionFile.writeAsString(output.join('\n'));

    print('✅ Created $fileName with ${players.length} players');

    // Show top 3 players for this position with FBRef stats
    if (players.isNotEmpty) {
      print('   Top players:');
      for (var i = 0; i < 3 && i < players.length; i++) {
        final player = players[i];
        final name = player[2].trim();
        final fvm = player[11].trim();
        final price = player[8].trim();
        final team = player[3].trim();
        final mp = player.length > 12 ? player[12].trim() : '0';
        final gls = player.length > 16 ? player[16].trim() : '0';
        final ast = player.length > 17 ? player[17].trim() : '0';
        print(
          '   ${i + 1}. $name ($team) - FVM: $fvm, Price: $price, MP: $mp, Gls: $gls, Ast: $ast',
        );
      }
    }
  }

  print('\n🎉 UPDATED POSITION FILES CREATED!');
  print('   Files created: ${playersByPosition.keys.length}');
  print(
    '   Total players processed: ${playersByPosition.values.fold(0, (sum, list) => sum + list.length)}',
  );
}
