# Team Configuration System

## Overview
The Super Bowl Squares game now supports dynamic team names through Firebase configuration, replacing the hardcoded "Steelers" and "Cowboys" names.

## Default Configuration
- **Home Team (Left/Vertical)**: AFC
- **Away Team (Top/Horizontal)**: NFC

## Features

### 1. Dynamic Team Names
- Team names are stored in Firebase `config` collection
- Names update in real-time across all users
- Maximum 20 characters per team name
- Automatically converts to uppercase for display

### 2. Admin Management
- Admin dashboard includes "Team Names" section
- Shows current team names with color-coded display:
  - Home team: Red theme
  - Away team: Blue theme
- "Edit Teams" button opens configuration dialog

### 3. Real-time Updates
- Changes propagate immediately to all users
- No refresh required
- Uses Firestore streams for instant synchronization

### 4. Game Board Display
- Team names spread evenly across axes:
  - Away team: Individual letters spread horizontally across top
  - Home team: Individual letters spread vertically down left side
- Maintains consistent styling with Rubik font

## Technical Implementation

### Models
- `GameConfigModel`: Stores team configuration
- Fields: `homeTeamName`, `awayTeamName`, `updatedAt`, `updatedBy`

### Services
- `GameConfigService`: Manages configuration CRUD operations
- Provides real-time stream for config updates
- Validates team names (1-20 characters)
- Creates default config if none exists

### UI Updates
- `SquaresGamePage`: Listens to config stream
- `AdminDashboard`: Provides team editing interface
- Dynamic rendering based on team name length

## Usage Examples

### Common Team Names
- **NFL Conferences**: AFC vs NFC
- **Specific Teams**: CHIEFS vs EAGLES
- **Custom Names**: TEAM1 vs TEAM2
- **Divisions**: EAST vs WEST

## Future Enhancements
- Team logos/colors
- Multiple game configurations
- Team name history
- Conference/division presets