class LeagueUtils {
  LeagueUtils._();

  static String normalize(String league) {
    final value = league.trim().toLowerCase();
    if (value == '1' ||
        value == '1.(roland garros)' ||
        value == '1. roland garros' ||
        value == '1. liga') {
      return '1';
    }
    if (value == '2' ||
        value == '2.(australian open)' ||
        value == '2. australian open' ||
        value == '2. liga') {
      return '2';
    }
    if (value == '3' ||
        value == '3.(wimbledon)' ||
        value == '3. wimbledon' ||
        value == '3. liga') {
      return '3';
    }
    if (value == '4' ||
        value == '4.(us open)' ||
        value == '4. us open' ||
        value == '4. liga') {
      return '4';
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
