class Question {
  final String text;
  final String answer;
  final List<String> characters;

  Question({
    required this.text,
    required this.answer,
    required this.characters,
  });

  // 文字を鏡文字に変換
  String get mirroredText {
    return text.split('').reversed.join('');
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'answer': answer,
      'characters': characters,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      text: map['text'] ?? '',
      answer: map['answer'] ?? '',
      characters: List<String>.from(map['characters'] ?? []),
    );
  }
}
