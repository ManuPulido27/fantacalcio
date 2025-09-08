#!/usr/bin/env python3
import pandas as pd
import sys
import os

def convert_excel_to_csv(excel_file, csv_file):
    """Convert Excel file to CSV format"""
    try:
        print(f"Converting {excel_file} to {csv_file}...")
        
        # Read Excel file
        df = pd.read_excel(excel_file)
        
        # Write to CSV
        df.to_csv(csv_file, index=False, encoding='utf-8')
        
        print(f"✓ Successfully converted {excel_file} to {csv_file}")
        print(f"  Rows: {len(df)}, Columns: {len(df.columns)}")
        
        return True
        
    except Exception as e:
        print(f"✗ Error converting {excel_file}: {e}")
        return False

def main():
    # Convert both Excel files to CSV
    files_to_convert = [
        ("Quotazioni_Fantacalcio_Stagione_2025_26.xlsx", "quotazioni_2025_26.csv"),
        ("Quotazioni_Fantacalcio_Stagione_2024_25.xlsx", "quotazioni_2024_25.csv")
    ]
    
    print("Converting Excel files to CSV format...")
    print("=" * 50)
    
    success_count = 0
    for excel_file, csv_file in files_to_convert:
        if os.path.exists(excel_file):
            if convert_excel_to_csv(excel_file, csv_file):
                success_count += 1
        else:
            print(f"✗ File not found: {excel_file}")
    
    print("=" * 50)
    print(f"Conversion complete: {success_count}/{len(files_to_convert)} files converted successfully")
    
    if success_count == len(files_to_convert):
        print("✓ All files converted! You can now run the Dart script.")
    else:
        print("⚠️  Some files failed to convert. Please check the errors above.")

if __name__ == "__main__":
    main()
