#!/usr/bin/env python3
"""
Convert FBRef tab-separated data to clean CSV format
Handles player statistics from Football Reference data
"""

import pandas as pd
import re
import sys
from pathlib import Path

def clean_player_name(name):
    """Clean player names by removing extra whitespace and standardizing format"""
    if not name or name.strip() == '':
        return name
    # Remove extra whitespace and standardize
    cleaned = ' '.join(name.split())
    return cleaned

def clean_team_name(team):
    """Clean team names"""
    if not team or team.strip() == '':
        return team
    return team.strip()

def clean_position(pos):
    """Clean and standardize position data"""
    if not pos or pos.strip() == '':
        return pos
    # Standardize position format
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
        # Read the tab-separated file
        # Skip the first line (empty) and use the second line as header
        df = pd.read_csv(input_file, sep='\t', skiprows=1, encoding='utf-8')
        
        print(f"Original data shape: {df.shape}")
        print(f"Columns: {list(df.columns)}")
        
        # Clean the data
        print("Cleaning data...")
        
        # Clean player names
        if 'Player' in df.columns:
            df['Player'] = df['Player'].apply(clean_player_name)
        
        # Clean team names
        if 'Squad' in df.columns:
            df['Squad'] = df['Squad'].apply(clean_team_name)
        
        # Clean positions
        if 'Pos' in df.columns:
            df['Pos'] = df['Pos'].apply(clean_position)
        
        # Clean numeric columns (remove commas, handle empty values)
        numeric_columns = ['MP', 'Starts', 'Min', '90s', 'Gls', 'Ast', 'G+A', 'G-PK', 
                          'PK', 'PKatt', 'CrdY', 'CrdR', 'xG', 'npxG', 'xAG', 'npxG+xAG',
                          'PrgC', 'PrgP', 'PrgR']
        
        for col in numeric_columns:
            if col in df.columns:
                df[col] = df[col].apply(clean_numeric_value)
        
        # Clean per-90 minute stats (columns that end with specific patterns)
        per_90_columns = [col for col in df.columns if any(col.endswith(suffix) for suffix in 
                        ['Gls', 'Ast', 'G+A', 'G-PK', 'G+A-PK', 'xG', 'xAG', 'xG+xAG', 'npxG', 'npxG+xAG'])]
        
        for col in per_90_columns:
            if col in df.columns:
                df[col] = df[col].apply(clean_numeric_value)
        
        # Remove duplicate rows based on Player and Squad
        initial_rows = len(df)
        df = df.drop_duplicates(subset=['Player', 'Squad'], keep='first')
        final_rows = len(df)
        
        if initial_rows != final_rows:
            print(f"Removed {initial_rows - final_rows} duplicate rows")
        
        # Sort by Player name for better organization
        df = df.sort_values('Player').reset_index(drop=True)
        
        # Save to CSV
        df.to_csv(output_file, index=False, encoding='utf-8')
        
        print(f"✅ Successfully converted to CSV: {output_file}")
        print(f"Final data shape: {df.shape}")
        print(f"Total players: {len(df)}")
        
        # Show sample of cleaned data
        print("\n📊 Sample of cleaned data:")
        print(df[['Player', 'Squad', 'Pos', 'Age', 'MP', 'Gls', 'Ast']].head(10).to_string(index=False))
        
        # Show position distribution
        if 'Pos' in df.columns:
            print(f"\n📈 Position distribution:")
            pos_counts = df['Pos'].value_counts()
            for pos, count in pos_counts.items():
                print(f"  {pos}: {count} players")
        
        # Show team distribution
        if 'Squad' in df.columns:
            print(f"\n🏟️  Team distribution (top 10):")
            team_counts = df['Squad'].value_counts().head(10)
            for team, count in team_counts.items():
                print(f"  {team}: {count} players")
        
        return True
        
    except Exception as e:
        print(f"❌ Error converting file: {str(e)}")
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
