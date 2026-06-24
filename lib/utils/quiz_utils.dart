import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:muslim/shared/constants.dart' as constants;

enum QuizQuestionType {
  singleSelection,
  multipleSelection,
  trueFalse,
  ordering,
  matching,
  unknown,
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.category,
    required this.question,
    required this.type,
    required this.options,
    required this.answers,
  });

  final String id;
  final String category;
  final String question;
  final QuizQuestionType type;
  final List<String> options;
  final List<String> answers;

  bool get isOrdering => type == QuizQuestionType.ordering;

  bool get allowsMultipleAnswers => type == QuizQuestionType.multipleSelection;

  bool get isSingleAnswer =>
      type == QuizQuestionType.singleSelection ||
      type == QuizQuestionType.trueFalse ||
      type == QuizQuestionType.matching ||
      type == QuizQuestionType.unknown;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final List<String> parsedOptions = _stringListFromJson(json['options']);
    final List<String> parsedAnswers = _stringListFromJson(json['answers']);

    return QuizQuestion(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      question: json['question']?.toString() ?? '',
      type: _parseType(json['type']?.toString()),
      options: parsedOptions,
      answers: parsedAnswers,
    );
  }

  bool isCorrectSelection(Set<String> selectedAnswers) {
    if (isOrdering) {
      return false;
    }
    return setEquals(selectedAnswers, answers.toSet());
  }

  bool isCorrectOrder(List<String> orderedOptions) {
    if (orderedOptions.length != answers.length) {
      return false;
    }
    for (int index = 0; index < answers.length; index++) {
      if (orderedOptions[index] != answers[index]) {
        return false;
      }
    }
    return true;
  }

  static QuizQuestionType _parseType(String? type) {
    switch (type) {
      case 'single_selection':
        return QuizQuestionType.singleSelection;
      case 'multiple_selection':
        return QuizQuestionType.multipleSelection;
      case 'true_false':
        return QuizQuestionType.trueFalse;
      case 'ordering':
        return QuizQuestionType.ordering;
      case 'matching':
        return QuizQuestionType.matching;
      default:
        return QuizQuestionType.unknown;
    }
  }

  static List<String> _stringListFromJson(dynamic value) {
    if (value is! Iterable) {
      return <String>[];
    }
    return value
        .map((dynamic item) => item?.toString().trim() ?? '')
        .where((String item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

Future<QuizQuestion> getRandomQuizQuestion() async {
  final Uri uri = Uri.parse(
    '${constants.MUSLIM_API_URL}quizes/get_random_quiz',
  );
  final http.Response response = await http.get(
    uri,
    headers: const <String, String>{'Access-Control-Allow-Origin': '*'},
  );

  if (response.statusCode != 200) {
    throw QuizFetchException('Quiz API returned ${response.statusCode}');
  }

  final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    throw const QuizFetchException('Quiz API returned an invalid response');
  }

  final QuizQuestion question = QuizQuestion.fromJson(decoded);
  if (question.question.isEmpty ||
      question.options.isEmpty ||
      question.answers.isEmpty) {
    throw const QuizFetchException('Quiz API returned an incomplete question');
  }

  return question;
}

class QuizFetchException implements Exception {
  const QuizFetchException(this.message);

  final String message;

  @override
  String toString() => message;
}
