class Player {
  final String id;
  final String name;
  final int score;
  final bool hasAnswered;
  final bool isCorrect;
  final String? answer; // プレイヤーの回答内容

  Player({
    required this.id,
    required this.name,
    this.score = 0,
    this.hasAnswered = false,
    this.isCorrect = false,
    this.answer,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'score': score,
      'hasAnswered': hasAnswered,
      'isCorrect': isCorrect,
      'answer': answer,
    };
  }

  factory Player.fromMap(Map<String, dynamic> map) {
    return Player(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      score: map['score'] ?? 0,
      hasAnswered: map['hasAnswered'] ?? false,
      isCorrect: map['isCorrect'] ?? false,
      answer: map['answer'],
    );
  }

  Player copyWith({
    String? id,
    String? name,
    int? score,
    bool? hasAnswered,
    bool? isCorrect,
    String? answer,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      hasAnswered: hasAnswered ?? this.hasAnswered,
      isCorrect: isCorrect ?? this.isCorrect,
      answer: answer ?? this.answer,
    );
  }
}
