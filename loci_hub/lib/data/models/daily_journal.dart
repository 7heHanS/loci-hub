class DailyJournal {
  final String journalDate; // YYYY-MM-DD
  final String? aiTitle;
  final String? aiSummary;
  final int createdAt; // UTC Epoch seconds
  final int updatedAt; // UTC Epoch seconds

  DailyJournal({
    required this.journalDate,
    this.aiTitle,
    this.aiSummary,
    required this.createdAt,
    required this.updatedAt,
  });

  DailyJournal copyWith({
    String? journalDate,
    String? aiTitle,
    String? aiSummary,
    int? createdAt,
    int? updatedAt,
  }) {
    return DailyJournal(
      journalDate: journalDate ?? this.journalDate,
      aiTitle: aiTitle ?? this.aiTitle,
      aiSummary: aiSummary ?? this.aiSummary,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'journal_date': journalDate,
      'ai_title': aiTitle,
      'ai_summary': aiSummary,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory DailyJournal.fromMap(Map<String, dynamic> map) {
    return DailyJournal(
      journalDate: map['journal_date'] as String,
      aiTitle: map['ai_title'] as String?,
      aiSummary: map['ai_summary'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
    );
  }

  @override
  String toString() {
    return 'DailyJournal(journalDate: $journalDate, aiTitle: $aiTitle, aiSummary: $aiSummary, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
