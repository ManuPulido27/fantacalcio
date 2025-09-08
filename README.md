# Fantacalcio ASTA (Auction Draft) Assistant

This project helps you prepare for and manage your Italian Fantacalcio auction draft by combining official player data from multiple seasons and providing real-time analysis during the auction.

## Overview

The Fantacalcio ASTA is an auction-style draft where managers bid on players to build their fantasy football team. This tool combines current season data with historical performance to help you make informed decisions.

## Data Sources

- **2025/26 Season CSV**: Filtered with 50% appearances to keep reliable players
- **2024/25 Season CSV**: Unfiltered historical data for reference and trend analysis

## Key Metrics

- **Qt.A**: Current price (Quotazione Attuale)
- **Qt.I**: Initial price (Quotazione Iniziale) 
- **Diff**: Price difference (Qt.A - Qt.I)
- **FVM**: Fantavoto Medio (average fantasy rating) - our main performance metric

## Features

### Data Preparation
- Combines 2025/26 player list with 2024/25 FVM data
- Merges historical performance metrics for trend analysis
- Ensures data consistency and validation

### Auction Management
- Track your purchases (player + role + price)
- Real-time budget monitoring
- Player value analysis (FVM vs price)
- Comparative player recommendations

### Strategic Analysis
- Identify undervalued players by comparing FVM to current prices
- Spot comebacks and hidden values using historical data
- Budget optimization recommendations
- Roster balance analysis

## Usage

1. **Prepare Data**: Run the CSV conversion script to merge season data
2. **During Auction**: Log your purchases and get real-time recommendations
3. **Analysis**: Use FVM comparisons to find bargains and make strategic decisions

## Files

- `csv_convert.dart`: Main script for merging CSV data
- `quotazioni_2025_26.csv`: Current season player data (filtered)
- `quotazioni_2024_25.csv`: Previous season data (unfiltered)
- `merged_2025_26.csv`: Combined dataset with historical FVM

## Strategy Notes

- Use FVM as the primary performance indicator
- Compare current prices to FVM to identify value picks
- Historical data helps spot players returning from injury or poor form
- Filtered 2025/26 data ensures consistency in your base player pool
- Unfiltered 2024/25 data helps discover hidden gems and comebacks
# fantacalcio
