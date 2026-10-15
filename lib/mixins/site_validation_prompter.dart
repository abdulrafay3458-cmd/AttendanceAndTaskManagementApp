// lib/mixins/site_validation_prompter.dart
//
// Add to your Dashboard State and a pending site-validation request pops up as a dialog:
//   - when the dashboard opens
//   - when the app returns from background
//   - when a Firebase notification arrives or is tapped (call handleSiteValidationMessage)
//   - every 60 s while the dashboard is open (safety net if a push is missed)
//
// See INTEGRATION_GUIDE.md section 10 for the four edits to dashboard.dart.

import 'dart:async';
import 'package:attendance_app/site_validation_dialog.dart';
import 'package:flutter/material.dart';
import '../models/site_validation_models.dart';
import '../services/site_validation_service.dart';

class _ResumeObserver with WidgetsBindingObserver {
  final VoidCallback onResumed;
  _ResumeObserver(this.onResumed);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResumed();
  }
}

mixin SiteValidationPrompter<T extends StatefulWidget> on State<T> {
  /// Provide it in your State, e.g.:
  ///   @override
  ///   late final SiteValidationService siteValidationService = SiteValidationService(yourDio);
  SiteValidationService get siteValidationService;
  StreamSubscription<Map<String, dynamic>>? _svBusSub;
  Timer? _svTimer;
  bool _svShowing = false;
  final Set<String> _svDismissed = {}; // closed with "Close": don't nag again until resume / tap
  late final _ResumeObserver _svObserver = _ResumeObserver(() {
    _svDismissed.clear();
    checkSiteValidations();
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_svObserver);
    _svTimer = Timer.periodic(const Duration(seconds: 60), (_) => checkSiteValidations());
    WidgetsBinding.instance.addPostFrameCallback((_) => checkSiteValidations());
  }

  @override
  void dispose() {
    _svTimer?.cancel();
    _svBusSub?.cancel(); 
    WidgetsBinding.instance.removeObserver(_svObserver);
    super.dispose();
  }

  /// Call from your existing Firebase listeners (onMessage, onMessageOpenedApp, getInitialMessage).
  /// Returns true when the message was a site-validation push and has been handled.
  bool handleSiteValidationMessage(Map<String, dynamic> data) {
    if (data['type'] != 'site_validation') return false;
    final id ='${data['validationId'] ?? ''}';
    checkSiteValidations(validationId: id);
    return true;
  }

  /// Shows the dialog for the given request, or for the first open one if no id is given.
  Future<void> checkSiteValidations({String? validationId}) async {
    if (!mounted || _svShowing) return;

    SiteValidationRequest? request;
    try {
      if (validationId != null) {
        final r = await siteValidationService.getById(validationId);
        if (r.isPending && r.canValidate) request = r;
      } else {
        final list = await siteValidationService.getPending();
        for (final r in list) {
          if (r.canValidate && !_svDismissed.contains(r.id)) {
            request = r;
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('Site validation check failed: $e'); // offline etc.: try again next tick
      return;
    }

    if (request == null || !mounted || _svShowing) return;

    _svShowing = true;
    final ok = await showSiteValidationDialog(context, service: siteValidationService, request: request);
    _svShowing = false;

    if (ok == true) {
      checkSiteValidations(); // another active task may be waiting
    } else {
      _svDismissed.add(request.id);
    }
  }
}
