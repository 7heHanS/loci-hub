enum MatchStatus {
  pending,                    // Scan completed, matching not attempted
  matched,                    // Matching succeeded
  unmatchedNoLocation,        // No location log for this date
  unmatchedOutOfTolerance;    // Location logs exist but exceed tolerance

  String toDbValue() {
    switch (this) {
      case MatchStatus.pending:
        return 'pending';
      case MatchStatus.matched:
        return 'matched';
      case MatchStatus.unmatchedNoLocation:
        return 'unmatched_no_location';
      case MatchStatus.unmatchedOutOfTolerance:
        return 'unmatched_out_of_tolerance';
    }
  }

  static MatchStatus fromDb(String? value) {
    if (value == null) return MatchStatus.pending;
    switch (value) {
      case 'pending':
        return MatchStatus.pending;
      case 'matched':
        return MatchStatus.matched;
      case 'unmatched_no_location':
        return MatchStatus.unmatchedNoLocation;
      case 'unmatched_out_of_tolerance':
        return MatchStatus.unmatchedOutOfTolerance;
      default:
        return MatchStatus.pending;
    }
  }
}
