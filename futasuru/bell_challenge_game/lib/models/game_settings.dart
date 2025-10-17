class DifficultyLevel {
  final String id;
  final String name;
  final int timeLimit;
  final String description;
  final String emoji;
  final String recommendedFor;

  const DifficultyLevel({
    required this.id,
    required this.name,
    required this.timeLimit,
    required this.description,
    required this.emoji,
    required this.recommendedFor,
  });

  static const List<DifficultyLevel> levels = [
    DifficultyLevel(
      id: 'slow',
      name: 'ゆっくり',
      timeLimit: 4,
      description: 'じっくり考えて楽しめます',
      emoji: '🐌',
      recommendedFor: 'お子様・初心者向け',
    ),
    DifficultyLevel(
      id: 'normal',
      name: 'ふつう',
      timeLimit: 3,
      description: 'バランスの良い難易度',
      emoji: '🚶',
      recommendedFor: '一般向け',
    ),
    DifficultyLevel(
      id: 'fast',
      name: 'はやい',
      timeLimit: 2,
      description: '瞬時の判断力が試されます',
      emoji: '🏃',
      recommendedFor: '経験者向け',
    ),
    DifficultyLevel(
      id: 'ultra',
      name: 'げきはや',
      timeLimit: 1,
      description: 'オンライン対応超高速モード',
      emoji: '⚡',
      recommendedFor: '上級者・オンライン向け',
    ),
  ];

  static DifficultyLevel? findById(String id) {
    try {
      return levels.firstWhere((level) => level.id == id);
    } catch (e) {
      return null;
    }
  }
}

class GameSettings {
  final int timeLimit;
  final int maxWins;
  final bool hapticFeedback;
  final bool soundEffects;
  final bool bgmEnabled;
  final double bgmVolume;
  final double seVolume;
  final DifficultyLevel selectedDifficulty;

  const GameSettings({
    required this.timeLimit,
    required this.maxWins,
    required this.hapticFeedback,
    required this.soundEffects,
    required this.bgmEnabled,
    required this.bgmVolume,
    required this.seVolume,
    required this.selectedDifficulty,
  });

  GameSettings copyWith({
    int? timeLimit,
    int? maxWins,
    bool? hapticFeedback,
    bool? soundEffects,
    bool? bgmEnabled,
    double? bgmVolume,
    double? seVolume,
    DifficultyLevel? selectedDifficulty,
  }) {
    return GameSettings(
      timeLimit: timeLimit ?? this.timeLimit,
      maxWins: maxWins ?? this.maxWins,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      soundEffects: soundEffects ?? this.soundEffects,
      bgmEnabled: bgmEnabled ?? this.bgmEnabled,
      bgmVolume: bgmVolume ?? this.bgmVolume,
      seVolume: seVolume ?? this.seVolume,
      selectedDifficulty: selectedDifficulty ?? this.selectedDifficulty,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'timeLimit': timeLimit,
      'maxWins': maxWins,
      'hapticFeedback': hapticFeedback,
      'soundEffects': soundEffects,
      'bgmEnabled': bgmEnabled,
      'bgmVolume': bgmVolume,
      'seVolume': seVolume,
      'selectedDifficultyId': selectedDifficulty.id,
    };
  }

  static GameSettings fromMap(Map<String, dynamic> map) {
    final difficultyId = map['selectedDifficultyId'] as String? ?? 'normal';
    final difficulty = DifficultyLevel.findById(difficultyId) ?? DifficultyLevel.levels[1];

    return GameSettings(
      timeLimit: map['timeLimit'] as int? ?? difficulty.timeLimit,
      maxWins: map['maxWins'] as int? ?? 3,
      hapticFeedback: map['hapticFeedback'] as bool? ?? true,
      soundEffects: map['soundEffects'] as bool? ?? true,
      bgmEnabled: map['bgmEnabled'] as bool? ?? true,
      bgmVolume: (map['bgmVolume'] as num?)?.toDouble() ?? 0.3,
      seVolume: (map['seVolume'] as num?)?.toDouble() ?? 0.8,
      selectedDifficulty: difficulty,
    );
  }

  static GameSettings get defaultSettings {
    return GameSettings(
      timeLimit: DifficultyLevel.levels[1].timeLimit,
      maxWins: 3,
      hapticFeedback: true,
      soundEffects: true,
      bgmEnabled: true,
      bgmVolume: 0.3,
      seVolume: 0.8,
      selectedDifficulty: DifficultyLevel.levels[1],
    );
  }
}