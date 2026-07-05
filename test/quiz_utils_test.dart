import 'package:flutter_test/flutter_test.dart';
import 'package:muslim/utils/quiz_utils.dart';

void main() {
  test('parses quiz questions and checks single selection answers', () {
    final QuizQuestion question = QuizQuestion.fromJson(<String, dynamic>{
      'id': 'quiz-00001',
      'category': 'القرآن الكريم',
      'question': 'ما أول سورة في المصحف؟',
      'type': 'single_selection',
      'options': <String>['الفاتحة', 'البقرة', 'الإخلاص'],
      'answers': <String>['الفاتحة'],
    });

    expect(question.id, 'quiz-00001');
    expect(question.type, QuizQuestionType.singleSelection);
    expect(question.isCorrectSelection(<String>{'الفاتحة'}), isTrue);
    expect(question.isCorrectSelection(<String>{'البقرة'}), isFalse);
  });

  test('checks multiple selection as a set and ordering as a sequence', () {
    final QuizQuestion multipleQuestion = QuizQuestion.fromJson(
      <String, dynamic>{
        'type': 'multiple_selection',
        'question': 'اختر المعوذتين',
        'category': 'القرآن الكريم',
        'options': <String>['الفلق', 'الناس', 'الكوثر'],
        'answers': <String>['الفلق', 'الناس'],
      },
    );
    final QuizQuestion orderingQuestion = QuizQuestion.fromJson(
      <String, dynamic>{
        'type': 'ordering',
        'question': 'رتب السور',
        'category': 'القرآن الكريم',
        'options': <String>['الناس', 'الفلق', 'الإخلاص'],
        'answers': <String>['الإخلاص', 'الفلق', 'الناس'],
      },
    );

    expect(
      multipleQuestion.isCorrectSelection(<String>{'الناس', 'الفلق'}),
      isTrue,
    );
    expect(multipleQuestion.isCorrectSelection(<String>{'الناس'}), isFalse);
    expect(
      orderingQuestion.isCorrectOrder(<String>['الإخلاص', 'الفلق', 'الناس']),
      isTrue,
    );
    expect(
      orderingQuestion.isCorrectOrder(<String>['الناس', 'الفلق', 'الإخلاص']),
      isFalse,
    );
  });
}
