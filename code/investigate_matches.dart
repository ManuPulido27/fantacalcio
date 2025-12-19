import 'dart:io';

void main() async {
  final mergedFile = File('merged_2025_26_with_fbref.csv');
  final fbrefFile = File('fbref_players_clean.csv');

  print('🔍 Investigating player matches in detail...\n');

  final mergedLines = await mergedFile.readAsLines();
  final fbrefLines = await fbrefFile.readAsLines();

  final mergedHeader = mergedLines[1].split(',');
  final nameIndex = mergedHeader.indexOf('Nome_Giocatore');
  final squadIndex = mergedHeader.indexOf('Squadra');
  final mpIndex = mergedHeader.indexOf('Partite_Giocate');

  // Build comprehensive FBRef lookup
  final fbrefLookup = <String, Map<String, String>>{};
  final fbrefHeader = fbrefLines[0].split(',');

  for (var i = 1; i < fbrefLines.length; i++) {
    final parts = fbrefLines[i].split(',');
    if (parts.length >= 5) {
      final playerName = parts[1].trim();
      final squad = parts[4].trim();

      final playerData = <String, String>{};
      for (var j = 0; j < parts.length && j < fbrefHeader.length; j++) {
        playerData[fbrefHeader[j]] = parts[j].trim();
      }

      // Create multiple keys for comprehensive lookup
      final keys = [
        '$playerName|$squad',
        normalizeName(playerName) + '|' + normalizeTeam(squad),
        playerName + '|' + normalizeTeam(squad),
        normalizeName(playerName) + '|' + squad,
        playerName.split(' ').last + '|' + squad,
        playerName.split(' ').last + '|' + normalizeTeam(squad),
        playerName.split(' ').first + '|' + squad,
        playerName.split(' ').first + '|' + normalizeTeam(squad),
      ];

      for (final key in keys) {
        fbrefLookup[key] = playerData;
      }
    }
  }

  print('📊 FBRef lookup contains ${fbrefLookup.length} entries');

  // Check specific players that were flagged as suspicious
  final suspiciousPlayers = [
    'Di Gregorio|Juventus',
    'Sommer|Inter',
    'Maignan|Milan',
    'Meret|Napoli',
    'Svilar|Roma',
  ];

  print('\n🔍 Investigating suspicious matches:');
  for (final playerKey in suspiciousPlayers) {
    final parts = playerKey.split('|');
    final playerName = parts[0];
    final squad = parts[1];

    print('\n--- $playerName ($squad) ---');

    // Check if player has FBRef data in merged file
    var hasData = false;
    var mergedMp = '';
    for (var i = 2; i < mergedLines.length; i++) {
      final mergedParts = mergedLines[i].split(',');
      if (mergedParts.length > nameIndex && mergedParts.length > squadIndex) {
        if (mergedParts[nameIndex].trim() == playerName &&
            mergedParts[squadIndex].trim() == squad) {
          mergedMp = mergedParts.length > mpIndex
              ? mergedParts[mpIndex].trim()
              : '';
          hasData = mergedMp.isNotEmpty;
          break;
        }
      }
    }

    print('Has FBRef data in merged: $hasData');
    if (hasData) {
      print('Merged MP value: $mergedMp');
    }

    // Check FBRef lookup
    final fbrefPlayer = fbrefLookup[playerKey];
    if (fbrefPlayer != null) {
      print('Found in FBRef lookup: YES');
      print('FBRef MP: ${fbrefPlayer['MP']}');
      print('FBRef Player name: ${fbrefPlayer['Player']}');
      print('FBRef Squad: ${fbrefPlayer['Squad']}');
    } else {
      print('Found in FBRef lookup: NO');

      // Try to find similar names
      print('Searching for similar names...');
      var foundSimilar = false;
      for (final entry in fbrefLookup.entries) {
        final keyParts = entry.key.split('|');
        final fbrefName = keyParts[0];
        final fbrefSquad = keyParts[1];

        if (normalizeName(fbrefName).contains(normalizeName(playerName)) ||
            normalizeName(playerName).contains(normalizeName(fbrefName))) {
          print(
            '  Similar: $fbrefName ($fbrefSquad) - MP: ${entry.value['MP']}',
          );
          foundSimilar = true;
        }
      }

      if (!foundSimilar) {
        print('  No similar names found');
      }
    }
  }

  // Check some successful matches
  print('\n✅ Checking successful matches:');
  final successfulPlayers = [
    'Carlos Augusto|Inter',
    'Patric|Lazio',
    'Juan Jesus|Napoli',
  ];

  for (final playerKey in successfulPlayers) {
    final parts = playerKey.split('|');
    final playerName = parts[0];
    final squad = parts[1];

    print('\n--- $playerName ($squad) ---');

    // Check merged data
    var mergedMp = '';
    for (var i = 2; i < mergedLines.length; i++) {
      final mergedParts = mergedLines[i].split(',');
      if (mergedParts.length > nameIndex && mergedParts.length > squadIndex) {
        if (mergedParts[nameIndex].trim() == playerName &&
            mergedParts[squadIndex].trim() == squad) {
          mergedMp = mergedParts.length > mpIndex
              ? mergedParts[mpIndex].trim()
              : '';
          break;
        }
      }
    }
    print('Merged MP: $mergedMp');

    // Check FBRef lookup
    final fbrefPlayer = fbrefLookup[playerKey];
    if (fbrefPlayer != null) {
      print('FBRef MP: ${fbrefPlayer['MP']}');
      print('Match: ${mergedMp == fbrefPlayer['MP'] ? 'YES' : 'NO'}');
    } else {
      print('Not found in FBRef lookup');
    }
  }

  // Count total matches and analyze
  var totalWithData = 0;
  var exactMatches = 0;
  var approximateMatches = 0;
  var noMatches = 0;

  for (var i = 2; i < mergedLines.length; i++) {
    final parts = mergedLines[i].split(',');
    if (parts.length > nameIndex && parts.length > squadIndex) {
      final playerName = parts[nameIndex].trim();
      final squad = parts[squadIndex].trim();
      final mp = parts.length > mpIndex ? parts[mpIndex].trim() : '';

      if (mp.isNotEmpty) {
        totalWithData++;

        final exactKey = '$playerName|$squad';
        final fbrefPlayer = fbrefLookup[exactKey];

        if (fbrefPlayer != null) {
          exactMatches++;
        } else {
          // Check for approximate matches
          var foundApproximate = false;
          for (final entry in fbrefLookup.entries) {
            final keyParts = entry.key.split('|');
            final fbrefName = keyParts[0];
            final fbrefSquad = keyParts[1];

            if ((normalizeName(fbrefName) == normalizeName(playerName) &&
                    normalizeTeam(fbrefSquad) == normalizeTeam(squad)) ||
                (fbrefName.contains(playerName) &&
                    fbrefSquad.contains(squad)) ||
                (playerName.contains(fbrefName) &&
                    squad.contains(fbrefSquad))) {
              foundApproximate = true;
              break;
            }
          }

          if (foundApproximate) {
            approximateMatches++;
          } else {
            noMatches++;
          }
        }
      }
    }
  }

  print('\n📊 Match analysis:');
  print('Total players with FBRef data: $totalWithData');
  print('Exact matches: $exactMatches');
  print('Approximate matches: $approximateMatches');
  print('No matches found: $noMatches');
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
