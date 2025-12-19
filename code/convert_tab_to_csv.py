#!/usr/bin/env python3
"""
Convert tab-separated data to clean CSV format
Handles any tab-separated data file
"""

import csv
import re
from pathlib import Path

def clean_value(value):
    """Clean any value by removing extra whitespace and handling special cases"""
    if not value or value.strip() == '' or value == '-':
        return ''
    
    # Remove extra whitespace
    cleaned = ' '.join(str(value).split())
    
    # Remove commas from numbers (e.g., "1,183" -> "1183")
    if re.match(r'^[\d,]+\.?\d*$', cleaned):
        cleaned = cleaned.replace(',', '')
    
    return cleaned

def clean_position(pos):
    """Clean and standardize position data"""
    if not pos or pos.strip() == '':
        return pos
    pos = pos.strip()
    # Handle multiple positions (e.g., "DF,MF" -> "DF/MF")
    if ',' in pos:
        pos = pos.replace(',', '/')
    return pos

def convert_tab_to_csv(input_file, output_file):
    """Convert tab-separated data to clean CSV"""
    
    print(f"Reading data from: {input_file}")
    
    try:
        # Read the file content
        with open(input_file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        
        if not content.strip():
            print("❌ File is empty or cannot be read!")
            return False
        
        # Split into lines
        lines = content.strip().split('\n')
        print(f"Found {len(lines)} lines")
        
        # Find the header line (look for line with tab separators)
        header_line = None
        data_start = 0
        
        for i, line in enumerate(lines):
            if '\t' in line and line.strip():
                header_line = line
                data_start = i + 1
                break
        
        if not header_line:
            print("❌ No header line found with tab separators!")
            return False
        
        # Parse headers
        headers = [h.strip() for h in header_line.split('\t')]
        print(f"Found {len(headers)} columns")
        print(f"Headers: {headers[:10]}...")  # Show first 10 headers
        
        # Process data lines
        cleaned_data = []
        player_count = 0
        duplicate_count = 0
        seen_players = set()
        
        for i, line in enumerate(lines[data_start:], data_start):
            if not line.strip() or '\t' not in line:
                continue
            
            parts = [p.strip() for p in line.split('\t')]
            
            # Ensure we have enough columns
            if len(parts) < len(headers):
                parts.extend([''] * (len(headers) - len(parts)))
            elif len(parts) > len(headers):
                parts = parts[:len(headers)]
            
            # Clean the data
            cleaned_row = []
            for j, value in enumerate(parts):
                if j < len(headers):
                    col_name = headers[j]
                    
                    # Special cleaning for specific columns
                    if 'Pos' in col_name:
                        cleaned_value = clean_position(value)
                    else:
                        cleaned_value = clean_value(value)
                    
                    cleaned_row.append(cleaned_value)
                else:
                    cleaned_row.append('')
            
            # Check for duplicates based on Player and Squad (if available)
            if len(cleaned_row) >= 2:
                # Try to find Player and Squad columns
                player_idx = None
                squad_idx = None
                
                for idx, header in enumerate(headers):
                    if 'Player' in header:
                        player_idx = idx
                    elif 'Squad' in header:
                        squad_idx = idx
                
                if player_idx is not None and squad_idx is not None:
                    player_key = f"{cleaned_row[player_idx]}_{cleaned_row[squad_idx]}"
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
        if cleaned_data:
            # Show first few columns for sample
            sample_headers = headers[:7] if len(headers) >= 7 else headers
            print(" | ".join(f"{h[:10]:10}" for h in sample_headers))
            print("-" * (len(" | ".join(f"{h[:10]:10}" for h in sample_headers))))
            
            for i, row in enumerate(cleaned_data[:10]):
                sample_row = row[:7] if len(row) >= 7 else row
                print(" | ".join(f"{str(cell)[:10]:10}" for cell in sample_row))
        
        # Show position distribution if Pos column exists
        pos_idx = None
        for idx, header in enumerate(headers):
            if 'Pos' in header:
                pos_idx = idx
                break
        
        if pos_idx is not None:
            pos_counts = {}
            for row in cleaned_data:
                if len(row) > pos_idx and row[pos_idx]:
                    pos = row[pos_idx]
                    pos_counts[pos] = pos_counts.get(pos, 0) + 1
            
            if pos_counts:
                print(f"\n📈 Position distribution:")
                for pos, count in sorted(pos_counts.items()):
                    print(f"  {pos}: {count} players")
        
        # Show team distribution if Squad column exists
        squad_idx = None
        for idx, header in enumerate(headers):
            if 'Squad' in header:
                squad_idx = idx
                break
        
        if squad_idx is not None:
            team_counts = {}
            for row in cleaned_data:
                if len(row) > squad_idx and row[squad_idx]:
                    team = row[squad_idx]
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
    
    success = convert_tab_to_csv(input_file, output_file)
    
    if success:
        print(f"\n🎉 Conversion completed successfully!")
        print(f"Clean CSV saved as: {output_file}")
    else:
        print(f"\n❌ Conversion failed!")

if __name__ == "__main__":
    main()
