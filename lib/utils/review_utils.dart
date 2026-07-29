import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helper.dart' as helper;
import 'shared_preference_methods.dart' as shared_preference_methods;

const String _reviewSubmittedPreferenceKey = 'inAppReviewSubmitted';
const String _reviewPromptAfterPreferenceKey = 'inAppReviewPromptAfter';

const Duration reviewDeclinedCooldown = Duration(days: 30);
const Duration reviewLaterCooldown = Duration(days: 7);

enum ReviewRequestResult {
  requested,
  alreadySubmitted,
  noNetwork,
  unavailable,
  web,
  failed,
}

Future<bool> hasSubmittedReview(Future<SharedPreferences> prefs) async {
  return await shared_preference_methods.getBoolData(
        prefs,
        _reviewSubmittedPreferenceKey,
      ) ??
      false;
}

Future<bool> shouldShowReviewPrompt(Future<SharedPreferences> prefs) async {
  if (kIsWeb) {
    return false;
  }
  if (await hasSubmittedReview(prefs)) {
    return false;
  }
  if (!await _isPromptCooldownExpired(prefs)) {
    return false;
  }
  if (!await helper.networkAccess()) {
    return false;
  }
  try {
    return InAppReview.instance.isAvailable();
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return false;
  }
}

Future<void> deferReviewPrompt(
  Future<SharedPreferences> prefs,
  Duration duration,
) async {
  final DateTime promptAfter = DateTime.now().add(duration);
  await shared_preference_methods.setStringData(
    prefs,
    _reviewPromptAfterPreferenceKey,
    promptAfter.toIso8601String(),
  );
}

Future<bool> _isPromptCooldownExpired(Future<SharedPreferences> prefs) async {
  final String? storedDate = await shared_preference_methods.getStringData(
    prefs,
    _reviewPromptAfterPreferenceKey,
    false,
  );
  if (storedDate == null || storedDate.isEmpty) {
    return true;
  }

  final DateTime? promptAfter = DateTime.tryParse(storedDate);
  if (promptAfter == null) {
    return true;
  }
  return !DateTime.now().isBefore(promptAfter);
}

Future<ReviewRequestResult> requestReviewIfAllowed(
  Future<SharedPreferences> prefs,
) async {
  if (kIsWeb) {
    return ReviewRequestResult.web;
  }
  if (await hasSubmittedReview(prefs)) {
    return ReviewRequestResult.alreadySubmitted;
  }
  if (!await helper.networkAccess()) {
    return ReviewRequestResult.noNetwork;
  }

  try {
    final InAppReview inAppReview = InAppReview.instance;
    if (!await inAppReview.isAvailable()) {
      return ReviewRequestResult.unavailable;
    }
    await inAppReview.requestReview();
    await shared_preference_methods.setBoolData(
      prefs,
      _reviewSubmittedPreferenceKey,
      true,
    );
    return ReviewRequestResult.requested;
  } catch (e) {
    if (kDebugMode) {
      print(e);
    }
    return ReviewRequestResult.failed;
  }
}
