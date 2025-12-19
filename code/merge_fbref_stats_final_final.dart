import 'dart:io';

void main() async {
  final fantacalcioFile = File('merged_2025_26.csv');
  final fbrefFile = File('fbref_players_clean.csv');
  final outputFile = File('merged_2025_26_with_fbref_final_final.csv');

  print('🔧 Starting FINAL FINAL FBRef statistics merge...');

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

  // Parse FBRef data using column indices directly
  final fbrefData = <String, List<String>>{};
  final fbrefHeader = fbrefLines[0].split(',');

  print('FBRef columns: ${fbrefHeader.length}');
  print('FBRef headers: ${fbrefHeader.take(10).join(", ")}...');

  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 2) {
      final playerName = parts[1].trim(); // Player column
      final squad = parts[4].trim(); // Squad column

      // Create multiple keys for better matching, prioritizing exact matches
      final keys = [
        '$playerName|$squad', // Exact match - HIGHEST PRIORITY
        normalizeName(playerName) +
            '|' +
            normalizeTeam(squad), // Normalized match
        playerName + '|' + normalizeTeam(squad), // Name exact, team normalized
        normalizeName(playerName) + '|' + squad, // Name normalized, team exact
        // Try with first name only
        playerName.split(' ').last + '|' + squad,
        playerName.split(' ').last + '|' + normalizeTeam(squad),
        // Try with last name only
        playerName.split(' ').first + '|' + squad,
        playerName.split(' ').first + '|' + normalizeTeam(squad),
      ];

      for (final key in keys) {
        fbrefData[key] = parts; // Store the raw parts array
      }
    }
  }

  print('Loaded ${fbrefData.length} FBRef player records (with multiple keys)');

  // Create new header with FBRef statistics
  final fantacalcioHeader = fantacalcioLines[1].split(',');

  // Define FBRef column mappings using CORRECT column indices
  final fbrefColumnMappings = {
    'MP': 'Partite_Giocate', // Column 8 - Total matches played
    'Starts': 'Partite_Titolare', // Column 9 - Total starts
    'Min': 'Minuti_Giocati', // Column 10 - Total minutes
    '90s': 'Partite_90_Minuti', // Column 11 - Total 90-minute games
    'Gls_Total': 'Gol_Totali', // Column 12 - TOTAL goals (not per-90)
    'Ast_Total': 'Assist_Totali', // Column 13 - TOTAL assists (not per-90)
    'G+A_Total': 'Gol_Plus_Assist', // Column 14 - TOTAL goals+assists
    'G-PK': 'Gol_Senza_Rigori', // Column 15 - TOTAL non-penalty goals
    'PK': 'Rigori_Realizzati', // Column 16 - TOTAL penalties scored
    'PKatt': 'Rigori_Tentati', // Column 17 - TOTAL penalties attempted
    'CrdY': 'Cartellini_Gialli', // Column 18 - TOTAL yellow cards
    'CrdR': 'Cartellini_Rossi', // Column 19 - TOTAL red cards
    'xG_Total': 'Expected_Goals', // Column 20 - TOTAL expected goals
    'npxG': 'Expected_Goals_Senza_Rigori', // Column 21 - TOTAL non-penalty xG
    'xAG_Total': 'Expected_Assist', // Column 22 - TOTAL expected assists
    'npxG+xAG':
        'Expected_Goals_Plus_Assist', // Column 23 - TOTAL expected goals+assists
    'PrgC': 'Progressioni_Con_Palla', // Column 24 - TOTAL progressive carries
    'PrgP': 'Progressioni_Passaggi', // Column 25 - TOTAL progressive passes
    'PrgR':
        'Progressioni_Ricezioni', // Column 26 - TOTAL progressive receptions
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

      // Try multiple matching strategies in order of priority
      List<String>? fbrefPlayer;

      // Strategy 1: Exact match (HIGHEST PRIORITY)
      fbrefPlayer = fbrefData['$playerName|$squad'];

      // Strategy 2: Normalized match
      if (fbrefPlayer == null) {
        fbrefPlayer =
            fbrefData[normalizeName(playerName) + '|' + normalizeTeam(squad)];
      }

      // Strategy 3: Name exact, team normalized
      if (fbrefPlayer == null) {
        fbrefPlayer = fbrefData[playerName + '|' + normalizeTeam(squad)];
      }

      // Strategy 4: Name normalized, team exact
      if (fbrefPlayer == null) {
        fbrefPlayer = fbrefData[normalizeName(playerName) + '|' + squad];
      }

      // Strategy 5: Try with last name only
      if (fbrefPlayer == null) {
        final lastName = playerName.split(' ').last;
        fbrefPlayer = fbrefData['$lastName|$squad'];
        if (fbrefPlayer == null) {
          fbrefPlayer = fbrefData['$lastName|${normalizeTeam(squad)}'];
        }
      }

      // Strategy 6: Try with first name only
      if (fbrefPlayer == null) {
        final firstName = playerName.split(' ').first;
        fbrefPlayer = fbrefData['$firstName|$squad'];
        if (fbrefPlayer == null) {
          fbrefPlayer = fbrefData['$firstName|${normalizeTeam(squad)}'];
        }
      }

      // Strategy 7: Try without team (just name) - LOWEST PRIORITY
      if (fbrefPlayer == null) {
        for (final entry in fbrefData.entries) {
          if (entry.key.startsWith('$playerName|') ||
              entry.key.startsWith('${normalizeName(playerName)}|') ||
              entry.key.startsWith('${playerName.split(' ').last}|') ||
              entry.key.startsWith('${playerName.split(' ').first}|')) {
            fbrefPlayer = entry.value;
            break;
          }
        }
      }

      final newRow = <String>[];

      // Add existing Fantacalcio data
      newRow.addAll(parts);

      // Add FBRef statistics using CORRECT column indices
      if (fbrefPlayer != null && fbrefPlayer.length >= 26) {
        // Use specific column indices to get TOTAL stats (not per-90)
        final mp = fbrefPlayer.length > 8 ? fbrefPlayer[8].trim() : '';
        final starts = fbrefPlayer.length > 9 ? fbrefPlayer[9].trim() : '';
        final min = fbrefPlayer.length > 10 ? fbrefPlayer[10].trim() : '';
        final games90 = fbrefPlayer.length > 11 ? fbrefPlayer[11].trim() : '';

        // Get TOTAL stats from the correct column indices
        final glsTotal = fbrefPlayer.length > 12
            ? fbrefPlayer[12].trim()
            : ''; // Column 12 - TOTAL goals
        final astTotal = fbrefPlayer.length > 13
            ? fbrefPlayer[13].trim()
            : ''; // Column 13 - TOTAL assists
        final gaTotal = fbrefPlayer.length > 14
            ? fbrefPlayer[14].trim()
            : ''; // Column 14 - TOTAL goals+assists
        final gpk = fbrefPlayer.length > 15 ? fbrefPlayer[15].trim() : '';
        final pk = fbrefPlayer.length > 16 ? fbrefPlayer[16].trim() : '';
        final pkatt = fbrefPlayer.length > 17 ? fbrefPlayer[17].trim() : '';
        final crdy = fbrefPlayer.length > 18 ? fbrefPlayer[18].trim() : '';
        final crdr = fbrefPlayer.length > 19 ? fbrefPlayer[19].trim() : '';
        final xg = fbrefPlayer.length > 20 ? fbrefPlayer[20].trim() : '';
        final npxg = fbrefPlayer.length > 21 ? fbrefPlayer[21].trim() : '';
        final xag = fbrefPlayer.length > 22 ? fbrefPlayer[22].trim() : '';
        final npxgxag = fbrefPlayer.length > 23 ? fbrefPlayer[23].trim() : '';
        final prgc = fbrefPlayer.length > 24 ? fbrefPlayer[24].trim() : '';
        final prgp = fbrefPlayer.length > 25 ? fbrefPlayer[25].trim() : '';
        final prgr = fbrefPlayer.length > 26 ? fbrefPlayer[26].trim() : '';

        newRow.addAll([
          mp,
          starts,
          min,
          games90,
          glsTotal,
          astTotal,
          gaTotal,
          gpk,
          pk,
          pkatt,
          crdy,
          crdr,
          xg,
          npxg,
          xag,
          npxgxag,
          prgc,
          prgp,
          prgr,
        ]);
      } else {
        // Add empty values if no FBRef data
        newRow.addAll([
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ]);
      }

      output.add(newRow.join(','));

      if (fbrefPlayer != null) {
        matchedPlayers++;
        if (sampleMatches.length < 15) {
          final mp = fbrefPlayer.length > 8 ? fbrefPlayer[8].trim() : '0';
          final gls = fbrefPlayer.length > 12 ? fbrefPlayer[12].trim() : '0';
          final ast = fbrefPlayer.length > 13 ? fbrefPlayer[13].trim() : '0';
          sampleMatches.add(
            '✓ $playerName ($squad): MP=$mp, Gls=$gls, Ast=$ast',
          );
        }
      } else {
        unmatchedPlayers++;
        if (sampleUnmatches.length < 10) {
          sampleUnmatches.add('✗ $playerName ($squad)');
        }
      }
    }
  }

  // Write the merged file
  await outputFile.writeAsString(output.join('\n'));

  print('\n=== FINAL FINAL MERGE RESULTS ===');
  print('✅ Final final merged file created: ${outputFile.path}');
  print('Total players: ${matchedPlayers + unmatchedPlayers}');
  print('Players with FBRef data: $matchedPlayers');
  print('Players without FBRef data: $unmatchedPlayers');

  final matchRate =
      ((matchedPlayers / (matchedPlayers + unmatchedPlayers)) * 100)
          .toStringAsFixed(1);
  print('Match rate: $matchRate%');

  if (sampleMatches.isNotEmpty) {
    print('\nSample matches (with FINAL FINAL data):');
    for (final match in sampleMatches) {
      print(match);
    }
  }

  if (sampleUnmatches.isNotEmpty) {
    print('\nSample unmatched:');
    for (final unmatch in sampleUnmatches.take(5)) {
      print(unmatch);
    }
  }

  // Create updated position files
  await createUpdatedPositionFiles(outputFile, newHeader);

  print('\n🎉 FINAL FINAL FBRef statistics merge completed!');
  print('✅ Now using TOTAL stats (not per-90 stats)');
  print('✅ Column mapping fixed to use correct indices');
  print('✅ Exact matching prioritized to avoid wrong player matches');
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

Future<void> createUpdatedPositionFiles(
  File mergedFile,
  List<String> header,
) async {
  print('\n=== CREATING FINAL FINAL POSITION FILES ===');

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
    final fileName = 'giocatori_${ruolo.toLowerCase()}_final_final.csv';
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

    // Show top 3 players for this position with FINAL FINAL FBRef stats
    if (players.isNotEmpty) {
      print('   Top players (FINAL FINAL data):');
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

  print('\n🎉 FINAL FINAL POSITION FILES CREATED!');
  print('   Files created: ${playersByPosition.keys.length}');
  print(
    '   Total players processed: ${playersByPosition.values.fold(0, (sum, list) => sum + list.length)}',
  );
}
