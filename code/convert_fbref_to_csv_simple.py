#!/usr/bin/env python3
"""
Convert FBRef tab-separated data to clean CSV format (no pandas required)
Handles player statistics from Football Reference data
"""

import csv
import re
from pathlib import Path

def clean_player_name(name):
    """Clean player names by removing extra whitespace and standardizing format"""
    if not name or name.strip() == '':
        return name
    return ' '.join(name.split())

def clean_team_name(team):
    """Clean team names"""
    if not team or team.strip() == '':
        return team
    return team.strip()

def clean_position(pos):
    """Clean and standardize position data"""
    if not pos or pos.strip() == '':
        return pos
    pos = pos.strip()
    # Handle multiple positions (e.g., "DF,MF" -> "DF/MF")
    if ',' in pos:
        pos = pos.replace(',', '/')
    return pos

def clean_numeric_value(value):
    """Clean numeric values, handling commas and empty values"""
    if not value or value.strip() == '' or value == '-':
        return ''
    
    # Remove commas from numbers (e.g., "1,183" -> "1183")
    cleaned = str(value).replace(',', '')
    
    # Try to convert to float to validate
    try:
        float(cleaned)
        return cleaned
    except ValueError:
        return value

def convert_fbref_to_csv(input_file, output_file):
    """Convert FBRef tab-separated data to clean CSV"""
    
    print(f"Reading data from: {input_file}")
    
    try:
        with open(input_file, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        # Skip empty lines and find the header
        data_lines = [line.strip() for line in lines if line.strip()]
        
        if len(data_lines) < 2:
            print("❌ Not enough data lines found!")
            return False
        
        # First non-empty line should be the header
        header_line = data_lines[0]
        headers = header_line.split('\t')
        
        print(f"Found {len(headers)} columns")
        print(f"Headers: {headers[:10]}...")  # Show first 10 headers
        
        # Process data lines
        cleaned_data = []
        player_count = 0
        duplicate_count = 0
        seen_players = set()
        
        for i, line in enumerate(data_lines[1:], 1):
            if not line.strip():
                continue
                
            parts = line.split('\t')
            
            # Ensure we have enough columns
            if len(parts) < len(headers):
                # Pad with empty strings if needed
                parts.extend([''] * (len(headers) - len(parts)))
            elif len(parts) > len(headers):
                # Truncate if too many
                parts = parts[:len(headers)]
            
            # Clean the data
            cleaned_row = []
            for j, value in enumerate(parts):
                if j < len(headers):
                    col_name = headers[j]
                    
                    # Clean based on column type
                    if col_name == 'Player':
                        cleaned_value = clean_player_name(value)
                    elif col_name == 'Squad':
                        cleaned_value = clean_team_name(value)
                    elif col_name == 'Pos':
                        cleaned_value = clean_position(value)
                    elif col_name in ['MP', 'Starts', 'Min', '90s', 'Gls', 'Ast', 'G+A', 'G-PK', 
                                    'PK', 'PKatt', 'CrdY', 'CrdR', 'xG', 'npxG', 'xAG', 'npxG+xAG',
                                    'PrgC', 'PrgP', 'PrgR']:
                        cleaned_value = clean_numeric_value(value)
                    else:
                        # For other columns, try to clean numeric values
                        cleaned_value = clean_numeric_value(value)
                    
                    cleaned_row.append(cleaned_value)
                else:
                    cleaned_row.append('')
            
            # Check for duplicates based on Player and Squad
            if len(cleaned_row) >= 2:
                player_key = f"{cleaned_row[1]}_{cleaned_row[4]}"  # Player_Squad
                if player_key in seen_players:
                    duplicate_count += 1
                    continue
                seen_players.add(player_key)
            
            cleaned_data.append(cleaned_row)
            player_count += 1
        
        print(f"Processed {player_count} players")
        if duplicate_count > 0:
            print(f"Removed {duplicate_count} duplicate entries")
        
        # Write to CSV
        with open(output_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(headers)
            writer.writerows(cleaned_data)
        
        print(f"✅ Successfully converted to CSV: {output_file}")
        print(f"Total players: {len(cleaned_data)}")
        
        # Show sample of cleaned data
        print("\n📊 Sample of cleaned data:")
        print("Player | Squad | Pos | Age | MP | Gls | Ast")
        print("-" * 50)
        for i, row in enumerate(cleaned_data[:10]):
            if len(row) >= 7:
                print(f"{row[1][:15]:15} | {row[4][:8]:8} | {row[3][:3]:3} | {row[5][:3]:3} | {row[6][:2]:2} | {row[8][:3]:3} | {row[9][:3]:3}")
        
        # Show position distribution
        pos_counts = {}
        for row in cleaned_data:
            if len(row) > 3 and row[3]:  # Pos column
                pos = row[3]
                pos_counts[pos] = pos_counts.get(pos, 0) + 1
        
        if pos_counts:
            print(f"\n📈 Position distribution:")
            for pos, count in sorted(pos_counts.items()):
                print(f"  {pos}: {count} players")
        
        # Show team distribution (top 10)
        team_counts = {}
        for row in cleaned_data:
            if len(row) > 4 and row[4]:  # Squad column
                team = row[4]
                team_counts[team] = team_counts.get(team, 0) + 1
        
        if team_counts:
            print(f"\n🏟️  Team distribution (top 10):")
            sorted_teams = sorted(team_counts.items(), key=lambda x: x[1], reverse=True)
            for team, count in sorted_teams[:10]:
                print(f"  {team}: {count} players")
        
        return True
        
    except Exception as e:
        print(f"❌ Error converting file: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def main():
    input_file = "new.txt"
    output_file = "fbref_players_clean.csv"
    
    if not Path(input_file).exists():
        print(f"❌ Input file '{input_file}' not found!")
        return
    
    success = convert_fbref_to_csv(input_file, output_file)
    
    if success:
        print(f"\n🎉 Conversion completed successfully!")
        print(f"Clean CSV saved as: {output_file}")
    else:
        print(f"\n❌ Conversion failed!")

if __name__ == "__main__":
    main()
