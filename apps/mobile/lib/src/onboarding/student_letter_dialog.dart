import 'package:flutter/material.dart';

import '../design_system/telegram_theme.dart';
import '../localization/app_localizations.dart';
import '../localization/translations_student_letter.dart';

Future<void> showStudentLetter(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const StudentLetterDialog(),
);

class StudentLetterDialog extends StatefulWidget {
  const StudentLetterDialog({super.key, this.onRead});

  final Future<void> Function()? onRead;

  @override
  State<StudentLetterDialog> createState() => _StudentLetterDialogState();
}

class _StudentLetterDialogState extends State<StudentLetterDialog> {
  bool _reachedEnd = false, _saving = false, _saveFailed = false;

  bool _observeScroll(ScrollNotification notification) {
    if (!_reachedEnd &&
        notification.depth == 0 &&
        notification.metrics.maxScrollExtent > 0 &&
        notification.metrics.extentAfter <= 1) {
      setState(() => _reachedEnd = true);
    }
    return false;
  }

  Future<void> _acknowledge() async {
    if (!_reachedEnd || _saving) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.onRead?.call();
      if (mounted && ModalRoute.isCurrentOf(context) == true) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HhTelegramPalette.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        key: const ValueKey('student-letter-dialog'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 560),
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 560,
          height: (MediaQuery.sizeOf(context).height * .8).clamp(0, 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Semantics(
                  headingLevel: 1,
                  child: Text(
                    hhText(context, studentLetterTitle),
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      NotificationListener<ScrollNotification>(
                        onNotification: _observeScroll,
                        child: SingleChildScrollView(
                          key: const ValueKey('student-letter-scroll'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Keep the action below the first viewport even
                              // when a wide screen fits the complete letter.
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight + 1,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    8,
                                    24,
                                    24,
                                  ),
                                  child: DefaultTextStyle(
                                    style: TextStyle(
                                      color: p.ink,
                                      fontFamily: 'StudentLetterSerif',
                                      fontFamilyFallback: const [
                                        'HhNotoSansSC',
                                      ],
                                      fontSize: 16,
                                      height: 1.85,
                                      letterSpacing: 0,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final paragraph
                                            in studentLetterParagraphs)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 20,
                                            ),
                                            child: Text(
                                              hhText(context, paragraph),
                                            ),
                                          ),
                                        Text(
                                          hhText(
                                            context,
                                            studentLetterSignature,
                                          ),
                                          textAlign: TextAlign.end,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  8,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (_saveFailed)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: Semantics(
                                          liveRegion: true,
                                          child: Text(
                                            hhText(context, '阅读记录未保存，请重试。'),
                                            style: TextStyle(color: p.error),
                                          ),
                                        ),
                                      ),
                                    Visibility(
                                      visible: _reachedEnd,
                                      maintainState: true,
                                      maintainAnimation: true,
                                      maintainSize: true,
                                      child: FilledButton(
                                        key: const ValueKey(
                                          'student-letter-read',
                                        ),
                                        onPressed: !_reachedEnd || _saving
                                            ? null
                                            : _acknowledge,
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(0, 52),
                                          padding: const EdgeInsets.all(16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          hhText(context, '我已阅读'),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
