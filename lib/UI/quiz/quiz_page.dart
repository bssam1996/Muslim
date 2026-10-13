import 'package:muslim/shared/app_theme.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:muslim/utils/quiz_utils.dart';

class QuizPageClass extends StatefulWidget {
  const QuizPageClass({super.key, this.loadQuestion});
  final Future<QuizQuestion> Function()? loadQuestion;

  @override
  State<QuizPageClass> createState() => _QuizPageClassState();
}

class _QuizPageClassState extends State<QuizPageClass>
    with SingleTickerProviderStateMixin {
  late final AnimationController _celebrationController;

  QuizQuestion? _question;
  bool _loading = true;
  bool _showAnswer = false;
  bool _hasAnswered = false;
  bool _isCorrect = false;
  String? _errorKey;
  Set<String> _selectedAnswers = <String>{};
  List<String> _orderedOptions = <String>[];
  Timer? _celebrationTimer;

  @override
  void initState() {
    super.initState();
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_fetchQuestion());
    });
  }

  @override
  void dispose() {
    _celebrationTimer?.cancel();
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuestion() async {
    setState(() {
      _loading = true;
      _errorKey = null;
      _question = null;
      _resetAnswerState();
    });

    try {
      final QuizQuestion question =
          await (widget.loadQuestion?.call() ?? getRandomQuizQuestion());
      if (!mounted) {
        return;
      }
      setState(() {
        _question = question;
        _orderedOptions = List<String>.from(question.options);
        _loading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorKey = 'Quiz_Load_Error';
        _loading = false;
      });
    }
  }

  void _resetAnswerState() {
    _showAnswer = false;
    _hasAnswered = false;
    _isCorrect = false;
    _selectedAnswers = <String>{};
    _orderedOptions = <String>[];
    _celebrationTimer?.cancel();
    _celebrationController.reset();
  }

  void _toggleOption(String option) {
    final QuizQuestion? question = _question;
    if (question == null || _hasAnswered) {
      return;
    }

    setState(() {
      if (question.allowsMultipleAnswers) {
        if (_selectedAnswers.contains(option)) {
          _selectedAnswers.remove(option);
        } else {
          _selectedAnswers.add(option);
        }
      } else {
        _selectedAnswers = <String>{option};
      }
    });
  }

  void _submitAnswer() {
    final QuizQuestion? question = _question;
    if (question == null || !_canSubmit || _hasAnswered) {
      return;
    }

    final bool correct = question.isOrdering
        ? question.isCorrectOrder(_orderedOptions)
        : question.isCorrectSelection(_selectedAnswers);

    setState(() {
      _hasAnswered = true;
      _isCorrect = correct;
    });

    if (correct) {
      _celebrate();
    }
  }

  void _celebrate() {
    _celebrationTimer?.cancel();
    _celebrationController.forward(from: 0);
    _celebrationTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) {
        return;
      }
      _celebrationController.reset();
    });
  }

  bool get _canSubmit {
    final QuizQuestion? question = _question;
    if (question == null) {
      return false;
    }
    if (question.isOrdering) {
      return _orderedOptions.length == question.options.length;
    }
    return _selectedAnswers.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.of(context).canvas,
      appBar: AppBar(
        backgroundColor: AppPalette.of(context).canvas,
        iconTheme: IconThemeData(color: AppPalette.of(context).text),
        title: Text(
          'Quiz_Title'.tr(),
          style: TextStyle(color: AppPalette.of(context).text),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  AppPalette.of(context).canvas,
                  AppPalette.of(context).canvas,
                  AppPalette.of(context).canvas,
                  AppPalette.of(context).canvas,
                  AppPalette.of(context).panel,
                  AppPalette.of(context).canvas,
                  AppPalette.of(context).canvas,
                ],
              ),
            ),
            child: SafeArea(child: _buildBody()),
          ),
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _celebrationController,
              builder: (BuildContext context, Widget? child) {
                if (!_celebrationController.isAnimating) {
                  return const SizedBox.shrink();
                }
                return CustomPaint(
                  painter: _CelebrationPainter(
                    progress: _celebrationController.value,
                    direction: Directionality.of(context),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                CircularProgressIndicator(color: AppPalette.of(context).accent),
                const SizedBox(height: 16),
                Text(
                  'Quiz_Loading'.tr(),
                  style: TextStyle(
                    color: AppPalette.of(context).text,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_errorKey != null || _question == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.58,
            child: _buildMessage(
              icon: Icons.quiz_outlined,
              text: (_errorKey ?? 'Quiz_Load_Error').tr(),
              action: ElevatedButton.icon(
                onPressed: _fetchQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppPalette.of(context).accent,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
                icon: const Icon(Icons.refresh),
                label: Text('Reload'.tr()),
              ),
            ),
          ),
        ],
      );
    }

    final QuizQuestion question = _question!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        Directionality(
          textDirection: TextDirection.rtl,
          child: Card(
            color: AppPalette.of(context).panel,
            elevation: 10,
            shadowColor: AppPalette.of(context).canvas,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppPalette.of(context).border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _buildCategoryHeader(question),
                  const SizedBox(height: 18),
                  Text(
                    question.question,
                    style: TextStyle(
                      color: AppPalette.of(context).text,
                      fontSize: 22,
                      height: 1.45,
                      fontFamily: 'Uthman',
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 20),
                  _buildAnswerInput(question),
                  const SizedBox(height: 16),
                  _buildResultMessage(),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: (!_canSubmit || _hasAnswered)
                        ? null
                        : _submitAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.of(context).accent,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondary,
                      disabledBackgroundColor: AppPalette.of(
                        context,
                      ).muted.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('Quiz_Check_Answer'.tr()),
                  ),
                  if (_showAnswer) ...<Widget>[
                    const SizedBox(height: 16),
                    _buildAnswerReveal(question),
                  ],
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: _showAnswer
                        ? null
                        : () {
                            setState(() {
                              _showAnswer = true;
                            });
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppPalette.of(context).accent,
                      side: BorderSide(color: AppPalette.of(context).accent),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text('Quiz_Show_Answer'.tr()),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : _fetchQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.of(context).accent,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward),
                    label: Text('Quiz_New_Question'.tr()),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    question.id,
                    style: TextStyle(
                      color: AppPalette.of(context).accent,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryHeader(QuizQuestion question) {
    return Row(
      children: <Widget>[
        Container(
          width: 46,
          height: 46,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppPalette.of(context).canvas,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppPalette.of(context).accent),
          ),
          child: Image.asset('assets/quiz/quiz.png'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                question.category,
                style: TextStyle(
                  color: AppPalette.of(context).accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Uthman',
                ),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 2),
              Text(
                _typeLabel(question.type),
                style: TextStyle(
                  color: AppPalette.of(context).text,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnswerInput(QuizQuestion question) {
    if (question.isOrdering) {
      return _buildOrderingInput(question);
    }

    return Column(
      children: question.options
          .map((String option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildOptionTile(question, option),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildOptionTile(QuizQuestion question, String option) {
    final bool selected = _selectedAnswers.contains(option);
    final bool selectedIncorrect =
        _hasAnswered &&
        !_isCorrect &&
        selected &&
        !question.answers.contains(option);
    final Color borderColor = selectedIncorrect
        ? Colors.redAccent
        : selected
        ? AppPalette.of(context).accent
        : AppPalette.of(context).border;
    final Color backgroundColor = selectedIncorrect
        ? Colors.red.withValues(alpha: 0.24)
        : selected
        ? AppPalette.of(context).accent.withValues(alpha: 0.28)
        : AppPalette.of(context).canvas.withValues(alpha: 0.72);

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _toggleOption(option),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                question.allowsMultipleAnswers
                    ? selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank
                    : selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? AppPalette.of(context).accent
                    : AppPalette.of(context).text,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option,
                  style: TextStyle(
                    color: AppPalette.of(context).text,
                    fontSize: 18,
                    height: 1.35,
                    fontFamily: 'Uthman',
                  ),
                  textAlign: TextAlign.start,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderingInput(QuizQuestion question) {
    final Color borderColor = _hasAnswered && !_isCorrect
        ? Colors.redAccent
        : AppPalette.of(context).border;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppPalette.of(context).canvas.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        primary: false,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _orderedOptions.length,
        onReorderItem: _hasAnswered
            ? (int oldIndex, int newIndex) {}
            : (int oldIndex, int newIndex) {
                setState(() {
                  final String item = _orderedOptions.removeAt(oldIndex);
                  _orderedOptions.insert(newIndex, item);
                });
              },
        proxyDecorator: (Widget child, int index, Animation<double> animation) {
          return Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.03).animate(animation),
              child: child,
            ),
          );
        },
        itemBuilder: (BuildContext context, int index) {
          final String option = _orderedOptions[index];
          return Card(
            key: ValueKey<String>('ordering-$option'),
            color: AppPalette.of(context).panel,
            margin: const EdgeInsets.symmetric(vertical: 5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: AppPalette.of(context).border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppPalette.of(context).accent,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
                child: Text('${index + 1}'),
              ),
              title: Text(
                option,
                style: TextStyle(
                  color: AppPalette.of(context).text,
                  fontSize: 18,
                  fontFamily: 'Uthman',
                ),
              ),
              trailing: ReorderableDragStartListener(
                index: index,
                enabled: !_hasAnswered,
                child: Icon(
                  Icons.drag_handle,
                  color: AppPalette.of(context).text,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultMessage() {
    if (!_hasAnswered) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _isCorrect
            ? AppPalette.of(context).accent.withValues(alpha: 0.28)
            : Colors.red.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isCorrect ? AppPalette.of(context).accent : Colors.redAccent,
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            _isCorrect ? Icons.celebration : Icons.error_outline,
            color: _isCorrect
                ? AppPalette.of(context).accent
                : Colors.redAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              (_isCorrect ? 'Quiz_Correct_Answer' : 'Quiz_Incorrect_Answer')
                  .tr(),
              style: TextStyle(
                color: AppPalette.of(context).text,
                fontSize: 16,
              ),
              textAlign: TextAlign.start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerReveal(QuizQuestion question) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppPalette.of(context).accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppPalette.of(context).accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Quiz_Answer'.tr(),
            style: TextStyle(
              color: AppPalette.of(context).accent,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 10),
          ...question.answers.asMap().entries.map((
            MapEntry<int, String> entry,
          ) {
            final String prefix = question.isOrdering
                ? '${entry.key + 1}. '
                : '';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '$prefix${entry.value}',
                style: TextStyle(
                  color: AppPalette.of(context).text,
                  fontSize: 18,
                  height: 1.35,
                  fontFamily: 'Uthman',
                ),
                textAlign: TextAlign.start,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required String text,
    required Widget action,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: AppPalette.of(context).accent, size: 56),
          const SizedBox(height: 16),
          Text(
            text,
            style: TextStyle(color: AppPalette.of(context).text, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          action,
        ],
      ),
    );
  }

  String _typeLabel(QuizQuestionType type) {
    switch (type) {
      case QuizQuestionType.multipleSelection:
        return 'Quiz_Type_Multiple'.tr();
      case QuizQuestionType.trueFalse:
        return 'Quiz_Type_True_False'.tr();
      case QuizQuestionType.ordering:
        return 'Quiz_Type_Ordering'.tr();
      case QuizQuestionType.matching:
        return 'Quiz_Type_Matching'.tr();
      case QuizQuestionType.singleSelection:
      case QuizQuestionType.unknown:
        return 'Quiz_Type_Single'.tr();
    }
  }
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({required this.progress, required this.direction});

  final double progress;
  final TextDirection direction;

  static final List<_CelebrationParticle> _particles =
      List<_CelebrationParticle>.generate(
        36,
        (int index) => _CelebrationParticle(index),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Offset origin = Offset(size.width / 2, size.height * 0.22);
    final double easedProgress = Curves.easeOutCubic.transform(progress);
    final double fade = (1 - progress).clamp(0.0, 1.0);

    for (final _CelebrationParticle particle in _particles) {
      final double directionMultiplier = direction == TextDirection.rtl
          ? -1
          : 1;
      final double x =
          math.cos(particle.angle) *
          particle.distance *
          easedProgress *
          directionMultiplier;
      final double y =
          math.sin(particle.angle) * particle.distance * easedProgress +
          220 * progress * progress;
      final Offset center = origin + Offset(x, y);

      paint.color = particle.color.withValues(alpha: fade);
      canvas.drawCircle(center, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.direction != direction;
  }
}

class _CelebrationParticle {
  _CelebrationParticle(int seed)
    : angle = -math.pi + (seed * 0.37),
      distance = 110 + ((seed * 41) % 120).toDouble(),
      radius = 4 + ((seed * 7) % 5).toDouble(),
      color = _colors[seed % _colors.length];

  final double angle;
  final double distance;
  final double radius;
  final Color color;

  static const List<Color> _colors = <Color>[
    Color(0xFF92E8F6),
    Color(0xFF92E8F6),
    Color(0xFFFFFFFF),
    Color.fromRGBO(255, 214, 102, 1),
    Color.fromRGBO(255, 132, 132, 1),
  ];
}
