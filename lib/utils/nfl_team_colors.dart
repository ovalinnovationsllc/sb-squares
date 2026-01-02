import 'package:flutter/material.dart';

class NFLTeamColors {
  final Color primary;
  final Color secondary;

  const NFLTeamColors(this.primary, this.secondary);

  static const Map<String, NFLTeamColors> teams = {
    // AFC East
    'bills': NFLTeamColors(Color(0xFF00338D), Color(0xFFC60C30)),
    'buffalo bills': NFLTeamColors(Color(0xFF00338D), Color(0xFFC60C30)),
    'dolphins': NFLTeamColors(Color(0xFF008E97), Color(0xFFF26A24)),
    'miami dolphins': NFLTeamColors(Color(0xFF008E97), Color(0xFFF26A24)),
    'patriots': NFLTeamColors(Color(0xFF002244), Color(0xFFC60C30)),
    'new england patriots': NFLTeamColors(Color(0xFF002244), Color(0xFFC60C30)),
    'jets': NFLTeamColors(Color(0xFF125740), Color(0xFFFFFFFF)),
    'new york jets': NFLTeamColors(Color(0xFF125740), Color(0xFFFFFFFF)),

    // AFC North
    'ravens': NFLTeamColors(Color(0xFF241773), Color(0xFF9E7C0C)),
    'baltimore ravens': NFLTeamColors(Color(0xFF241773), Color(0xFF9E7C0C)),
    'bengals': NFLTeamColors(Color(0xFFFB4F14), Color(0xFF000000)),
    'cincinnati bengals': NFLTeamColors(Color(0xFFFB4F14), Color(0xFF000000)),
    'browns': NFLTeamColors(Color(0xFF311D00), Color(0xFFFF3C00)),
    'cleveland browns': NFLTeamColors(Color(0xFF311D00), Color(0xFFFF3C00)),
    'steelers': NFLTeamColors(Color(0xFF101820), Color(0xFFFFB612)),
    'pittsburgh steelers': NFLTeamColors(Color(0xFF101820), Color(0xFFFFB612)),

    // AFC South
    'texans': NFLTeamColors(Color(0xFF03202F), Color(0xFFA71930)),
    'houston texans': NFLTeamColors(Color(0xFF03202F), Color(0xFFA71930)),
    'colts': NFLTeamColors(Color(0xFF002C5F), Color(0xFFFFFFFF)),
    'indianapolis colts': NFLTeamColors(Color(0xFF002C5F), Color(0xFFFFFFFF)),
    'jaguars': NFLTeamColors(Color(0xFF006778), Color(0xFFD7A22A)),
    'jacksonville jaguars': NFLTeamColors(Color(0xFF006778), Color(0xFFD7A22A)),
    'titans': NFLTeamColors(Color(0xFF0C2340), Color(0xFF4B92DB)),
    'tennessee titans': NFLTeamColors(Color(0xFF0C2340), Color(0xFF4B92DB)),

    // AFC West
    'broncos': NFLTeamColors(Color(0xFFFB4F14), Color(0xFF002244)),
    'denver broncos': NFLTeamColors(Color(0xFFFB4F14), Color(0xFF002244)),
    'chiefs': NFLTeamColors(Color(0xFFE31837), Color(0xFFFFB81C)),
    'kansas city chiefs': NFLTeamColors(Color(0xFFE31837), Color(0xFFFFB81C)),
    'raiders': NFLTeamColors(Color(0xFF000000), Color(0xFFA5ACAF)),
    'las vegas raiders': NFLTeamColors(Color(0xFF000000), Color(0xFFA5ACAF)),
    'chargers': NFLTeamColors(Color(0xFF0080C6), Color(0xFFFFC20E)),
    'los angeles chargers': NFLTeamColors(Color(0xFF0080C6), Color(0xFFFFC20E)),

    // NFC East
    'cowboys': NFLTeamColors(Color(0xFF003594), Color(0xFF869397)),
    'dallas cowboys': NFLTeamColors(Color(0xFF003594), Color(0xFF869397)),
    'giants': NFLTeamColors(Color(0xFF0B2265), Color(0xFFA71930)),
    'new york giants': NFLTeamColors(Color(0xFF0B2265), Color(0xFFA71930)),
    'eagles': NFLTeamColors(Color(0xFF004C54), Color(0xFFA5ACAF)),
    'philadelphia eagles': NFLTeamColors(Color(0xFF004C54), Color(0xFFA5ACAF)),
    'commanders': NFLTeamColors(Color(0xFF5A1414), Color(0xFFFFB612)),
    'washington commanders': NFLTeamColors(Color(0xFF5A1414), Color(0xFFFFB612)),

    // NFC North
    'bears': NFLTeamColors(Color(0xFF0B162A), Color(0xFFC83803)),
    'chicago bears': NFLTeamColors(Color(0xFF0B162A), Color(0xFFC83803)),
    'lions': NFLTeamColors(Color(0xFF0076B6), Color(0xFFB0B7BC)),
    'detroit lions': NFLTeamColors(Color(0xFF0076B6), Color(0xFFB0B7BC)),
    'packers': NFLTeamColors(Color(0xFF203731), Color(0xFFFFB612)),
    'green bay packers': NFLTeamColors(Color(0xFF203731), Color(0xFFFFB612)),
    'vikings': NFLTeamColors(Color(0xFF4F2683), Color(0xFFFFC62F)),
    'minnesota vikings': NFLTeamColors(Color(0xFF4F2683), Color(0xFFFFC62F)),

    // NFC South
    'falcons': NFLTeamColors(Color(0xFFA71930), Color(0xFF000000)),
    'atlanta falcons': NFLTeamColors(Color(0xFFA71930), Color(0xFF000000)),
    'panthers': NFLTeamColors(Color(0xFF0085CA), Color(0xFF101820)),
    'carolina panthers': NFLTeamColors(Color(0xFF0085CA), Color(0xFF101820)),
    'saints': NFLTeamColors(Color(0xFFD3BC8D), Color(0xFF101820)),
    'new orleans saints': NFLTeamColors(Color(0xFFD3BC8D), Color(0xFF101820)),
    'buccaneers': NFLTeamColors(Color(0xFFD50A0A), Color(0xFF34302B)),
    'tampa bay buccaneers': NFLTeamColors(Color(0xFFD50A0A), Color(0xFF34302B)),
    'bucs': NFLTeamColors(Color(0xFFD50A0A), Color(0xFF34302B)),

    // NFC West
    'cardinals': NFLTeamColors(Color(0xFF97233F), Color(0xFF000000)),
    'arizona cardinals': NFLTeamColors(Color(0xFF97233F), Color(0xFF000000)),
    'rams': NFLTeamColors(Color(0xFF003594), Color(0xFFFFA300)),
    'los angeles rams': NFLTeamColors(Color(0xFF003594), Color(0xFFFFA300)),
    '49ers': NFLTeamColors(Color(0xFFAA0000), Color(0xFFB3995D)),
    'san francisco 49ers': NFLTeamColors(Color(0xFFAA0000), Color(0xFFB3995D)),
    'niners': NFLTeamColors(Color(0xFFAA0000), Color(0xFFB3995D)),
    'seahawks': NFLTeamColors(Color(0xFF002244), Color(0xFF69BE28)),
    'seattle seahawks': NFLTeamColors(Color(0xFF002244), Color(0xFF69BE28)),

    // Conference defaults
    'afc': NFLTeamColors(Color(0xFFD50A0A), Color(0xFFFFFFFF)),
    'nfc': NFLTeamColors(Color(0xFF003594), Color(0xFFFFFFFF)),
  };

  /// Get team colors by name (case-insensitive)
  static NFLTeamColors? getTeamColors(String teamName) {
    final normalized = teamName.toLowerCase().trim();
    return teams[normalized];
  }

  /// Get primary color for a team, with fallback
  static Color getPrimaryColor(String teamName, {Color fallback = const Color(0xFF2E7D32)}) {
    return getTeamColors(teamName)?.primary ?? fallback;
  }

  /// Get secondary color for a team, with fallback
  static Color getSecondaryColor(String teamName, {Color fallback = Colors.white}) {
    return getTeamColors(teamName)?.secondary ?? fallback;
  }
}
