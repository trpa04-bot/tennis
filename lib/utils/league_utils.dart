class LeagueUtils {
  LeagueUtils._();

  static String normalize(String league) {
    final value = league.trim().toLowerCase();
    if (value.isEmpty) {
      return '';
    }

    if (value.contains('roland') || value.contains('garros')) {
      return '1';
    }
    if (value.contains('australian') || value.contains('ao')) {
      return '2';
    }
    if (value.contains('wimbledon')) {
      return '3';
    }
    if (value.contains('us open') || value.contains('usopen')) {
      return '4';
    }

    final leadingDigit = RegExp(
      r'^[^0-9]*([1-4])(?:[^0-9]|$)',
    ).firstMatch(value);
    if (leadingDigit != null) {
      return leadingDigit.group(1)!;
    }

    return league;
  }

  static String label(String league) {
    switch (normalize(league)) {
      case '1':
        return '1.(ROLAND GARROS)';
      case '2':
        return '2.(AUSTRALIAN OPEN)';
      case '3':
        return '3.(WIMBLEDON)';
      case '4':
        return '4.(US OPEN)';
      default:
        return league;
    }
  }
}
