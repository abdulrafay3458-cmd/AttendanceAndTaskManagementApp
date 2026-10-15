// lib/services/work_notification_router.dart
//
// Routes the work-session pushes to the task they are about:
//   work_session_reminder             "Your scheduled working time ends in 15 minutes..."
//   work_session_auto_stopped         "Your session was stopped automatically..."
//   work_session_auto_stopped_alert   (Team Head) "<employee>'s session was stopped automatically..."
// Every one of them carries assignmentId + taskTitle in the FCM data payload.
//
// Wire it ONCE (e.g. in AttendanceApp.initState / after runApp), pointing at the screen that shows a task:
//
//   WorkNotificationRouter.attach((assignmentId, taskTitle) {
//     navigatorKey.currentState?.push(MaterialPageRoute(
//       builder: (_) => YourTaskScreen(assignmentId: assignmentId, taskTitle: taskTitle),
//     ));
//   });
//
// A tap that arrives before attach() (app launched from the notification) is remembered and replayed.

class WorkNotificationRouter {
  WorkNotificationRouter._();

  static void Function(String assignmentId, String taskTitle)? _open;
  static Map<String, dynamic>? _pending;

  static const _types = {
    'work_session_reminder',
    'work_session_auto_stopped',
    'work_session_auto_stopped_alert',
  };

  static void attach(void Function(String assignmentId, String taskTitle) open) {
    _open = open;
    final p = _pending;
    _pending = null;
    if (p != null) handle(p);
  }

  /// Call from notification-TAP handlers (onMessageOpenedApp, getInitialMessage).
  /// Returns true when the message was a work-session push (handled or queued).
  static bool handle(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || !_types.contains(type)) return false;

    final id = data['assignmentId']?.toString() ?? '';
    if (id.isEmpty) return true; // ours, but nothing to open

    final open = _open;
    if (open == null) {
      _pending = data; // navigator/screen not ready yet
      return true;
    }
    open(id, (data['taskTitle'] ?? 'Task').toString());
    return true;
  }
}
