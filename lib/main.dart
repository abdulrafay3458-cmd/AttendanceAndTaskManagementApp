import 'dart:io';
import 'dart:ui';
import 'package:attendance_app/SplashScreen.dart';
import 'package:attendance_app/adminscreen.dart';
import 'package:attendance_app/attendanceHistory.dart';
import 'package:attendance_app/dashboard.dart';
import 'package:attendance_app/firebase_options.dart';
import 'package:attendance_app/leavescreen.dart';
import 'package:attendance_app/login.dart';
import 'package:attendance_app/managerpanel.dart';
import 'package:attendance_app/models/AttendanceRecord.dart';
import 'package:attendance_app/models/employee.dart';
import 'package:attendance_app/my_tasks_screen.dart';
import 'package:attendance_app/profile.dart';
import 'package:attendance_app/reportscreen.dart';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/work_service.dart';
import 'package:attendance_app/site_validation_bus.dart';
import 'package:attendance_app/taskscreen.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:attendance_app/widgets/app_date.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:math';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

// ============================================
// CONFIGURATION
// ============================================
const String API_BASE_URL = 'http://103.104.192.247:1122/api/';
const String SIGNALR_URL = 'http://103.104.192.247:1122/attendanceHub';

// ============================================
// LOCAL NOTIFICATIONS INSTANCE
// ============================================
final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

// ============================================
// SETUP LOCAL NOTIFICATIONS (Android + iOS)
// ============================================
Future<void> setupLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    defaultPresentAlert: true,
    defaultPresentBadge: true,
    defaultPresentSound: true,
  );

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  await localNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('🔔 Notification tapped: ${response.payload}');
    },
  );

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Used for important notifications',
    importance: Importance.max,
  );

  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(channel);
}

// ============================================
// FIREBASE BACKGROUND MESSAGE HANDLER
// ============================================
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
 if (!Platform.isAndroid) return;   // ← add

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  print('📩 Background message: ${message.notification?.title}');

  if (Platform.isAndroid) {
    await setupLocalNotifications();

    if (message.notification != null) {
      await localNotifications.show(
        message.hashCode,
        message.notification!.title,
        message.notification!.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }
}

// ============================================
// FCM SETUP — SAFE VERSION (Android + iOS)
// ============================================
Future<void> setupFCM() async {
    if (!Platform.isAndroid) {         // ← add
    print('ℹ️ FCM skipped on iOS');
    return;
  }
  try {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permission (required for iOS)
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
    );

    print('📲 FCM Permission: ${settings.authorizationStatus}');

    // iOS foreground notification presentation options
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token — may fail on iOS without APNs key, handle gracefully
    try {
      String? token = await messaging
          .getToken()
          .timeout(const Duration(seconds: 5));
      print('🔑 FCM Token: $token');
      if (token != null) {
        await ApiService().sendTokenToBackend(token);
      }
    } catch (e) {
      // Non-fatal: token fails on iOS without APNs key
      print('⚠️ FCM Token failed (no APNs key?): $e');
    }

    // Token refresh listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      print('🔄 FCM Token refreshed: $newToken');
      ApiService().sendTokenToBackend(newToken);
    });

    // Foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      try {
        print('🔥 FOREGROUND MESSAGE RECEIVED');
        print('Data: ${message.data}');
        print('Title: ${message.notification?.title}');

        SiteValidationBus.instance.emit(message.data);

        if (message.notification != null) {
          localNotifications.show(
            message.hashCode,
            message.notification!.title,
            message.notification!.body,
            NotificationDetails(
              android: const AndroidNotificationDetails(
                'high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'Used for important notifications',
                importance: Importance.max,
                priority: Priority.high,
                showWhen: true,
                icon: '@mipmap/ic_launcher',
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                badgeNumber: 1,
                interruptionLevel: InterruptionLevel.active,
              ),
            ),
          );
          print('🔔 Notification shown: ${message.notification!.title}');
        }
      } catch (e) {
        print('❌ Local notification error: $e');
      }
    });

    // Notification tap — app in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('📲 Notification tapped from background');
      SiteValidationBus.instance.emit(message.data);
    });

    // App opened from terminated state via notification
    try {
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        print('🚀 App opened from terminated state via notification');
        SiteValidationBus.instance.emit(initialMessage.data);
      }
    } catch (e) {
      print('❌ Initial message error: $e');
    }
  } catch (e) {
    // FCM failure must NEVER crash the app
    print('❌ FCM Setup failed (non-fatal): $e');
  }
}

// ============================================
// LOADING APP — shows immediately on startup
// ============================================
class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.blue),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// ERROR APP — shows if something critical fails
// ============================================
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'App Error',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// MAIN ENTRY POINT — SAFE INITIALIZATION
// ============================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show loading screen IMMEDIATELY — prevents white screen
  runApp(const LoadingApp());
// 1. Firebase (Android only for now)
  if (Platform.isAndroid) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('✅ Firebase initialized');
    } catch (e) {
      print('❌ Firebase error: $e');
      runApp(ErrorApp(error: 'Firebase failed: $e'));
      return;
    }

  // 2. Background handler
try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      print('✅ Background handler registered');
    } catch (e) {
      print('❌ Background handler error: $e');
    }

  // 3. Local notifications
  try {
    await setupLocalNotifications();
    print('✅ Local notifications setup');
  } catch (e) {
    print('❌ Local notifications error: $e');
  }

  // 4. FCM — wrapped so it never crashes app
  try {
    await setupFCM();
    print('✅ FCM setup done');
  } catch (e) {
    print('❌ FCM error (non-fatal): $e');
  }

  // 5. API Service
  try {
    await ApiService.init();
    print('✅ API Service initialized');
  } catch (e) {
    print('❌ API Service error: $e');
  }

  // 6. Cameras
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
    print('✅ Cameras found: ${cameras.length}');
  } catch (e) {
    print('❌ Camera init error: $e');
  }

  // 7. Run actual app — replaces LoadingApp
  runApp(AttendanceApp(cameras: cameras));
}

// ============================================
// SIGNALR SERVICE
// ============================================
class SignalRService {
  HubConnection? _hubConnection;
  Function(Map<String, dynamic>)? onAttendanceUpdate;
  Function(Map<String, dynamic>)? onNotificationReceived;

  Future<void> connect() async {
    try {
      print('🔌 Connecting to SignalR...');

      var token = ApiService.authToken;

      if (token == null) {
        print('❌ Token is null, cannot connect SignalR');
        return;
      }

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            SIGNALR_URL,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
            ),
          )
          .build();

      _hubConnection!.on('ReceiveAttendanceUpdate', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final data = arguments[0] as Map<String, dynamic>;
          if (onAttendanceUpdate != null) {
            onAttendanceUpdate!(data);
          }
        }
      });

      _hubConnection!.on('ReceiveNotification', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          final data = arguments[0] as Map<String, dynamic>;
          if (onNotificationReceived != null) {
            onNotificationReceived!(data);
          }
        }
      });

      await _hubConnection!.start();
      print('✅ SignalR connected');
    } catch (e) {
      print('❌ SignalR error: $e');
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      print('🔌 SignalR disconnected');
    }
  }
}

// ============================================
// GLOBAL KEYS
// ============================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<State<DashboardScreen>> dashboardKey =
    GlobalKey<State<DashboardScreen>>();

// ============================================
// MAIN APP WIDGET
// ============================================
class AttendanceApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const AttendanceApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue[200]!,
        ),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      home: const SplashScreen(),
    );
  }
}

// ============================================
// HOME SCREEN
// ============================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final SignalRService _signalR = SignalRService();
  Employee? get employee => ApiService.currentEmployee;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _connectSignalR();

    if (employee?.isDeviceRegistered == false &&
        employee?.anyDeviceRegistered == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleFirstTimeLoginState();
      });
    }
  }

  Future<void> _handleFirstTimeLoginState() async {
    if (employee?.isDeviceRegistered == true) return;

    final shouldRequest = await _showRegisterDeviceDialogBlur();

    if (shouldRequest == true) {
      setState(() => _isLoading = true);
      bool result = await _sendDeviceRegistrationRequest();

      if (result) {
        setState(() {
          ApiService.currentEmployee?.AppliedDeviceRegistration = true;
        });
        setState(() => _isLoading = false);
        await _showRequestSentDialogBlur();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
    }
  }

  Future<void> _connectSignalR() async {
    await _signalR.connect();

    _signalR.onAttendanceUpdate = (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Attendance updated: ${data['employeeName']} at ${data['checkInTime']}',
          ),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {});
    };

    _signalR.onNotificationReceived = (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['title'] ?? 'Notification',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(data['message'] ?? ''),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _selectedIndex = 3;
              });
            },
          ),
        ),
      );
      setState(() {});
    };
  }

  Future<void> _showRequestSentDialogBlur() {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AlertDialog(
            title: const Text('Request Sent'),
            content: const Text(
              'Your request has been sent to admin.\n\nPlease wait for approval.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool?> _showRegisterDeviceDialogBlur() {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AlertDialog(
            title: const Text('New Device'),
            content: const Text(
              'This device is not registered.\n\nDo you want to request registration?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _sendDeviceRegistrationRequest() async {
    try {
      final result = await ApiService.requestToRegisterUserDevice();
      if (result == true) {
        print('✅ Device registration request successful');
        return true;
      } else {
        print('❌ Device registration request failed');
        return false;
      }
    } catch (e) {
      print('❌ Error sending request: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _signalR.disconnect();
    super.dispose();
  }

  List<Widget> get _screens {
    final role = employee?.role.map((r) => r.toLowerCase()).toList() ?? [];
    final workService = WorkService(ApiClient().dio);

    return [
      DashboardScreen(key: dashboardKey),
      MyTasksScreen(service: workService),
      AttendanceHistoryScreen(),
      LeaveScreen(),
      ReportsScreen(),
      if (role.contains('admin'))
        Adminscreen(
          companyId: ApiService.currentEmployee!.companyGuid,
          currentEmployeeId: ApiService.currentEmployee!.empGuid,
          currentEmployeeCode: ApiService.currentEmployee!.employeeCode,
        ),
      if (role.contains('manager')) ManagerPanel(),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (ApiService.isFirstTimeLogin) {
      return Scaffold(
        body: Container(color: Colors.black.withOpacity(0.2)),
      );
    }

    final role = employee?.role.map((r) => r.toLowerCase()).toList() ?? [];
    final isAdmin = role.contains('admin');
    final isManager = role.contains('manager');

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            label: 'Tasks',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'History',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event_busy),
            label: 'Leave',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_chart_outlined),
            label: 'Reports',
          ),
          if (isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
          if (isManager)
            const BottomNavigationBarItem(
              icon: Icon(Icons.supervisor_account_outlined),
              label: 'Manager',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================
// NOTIFICATIONS SCREEN
// ============================================
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final employeeId = ApiService.employeeId;
    if (employeeId != null) {
      final data = await ApiService.getNotifications(employeeId);
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.f(20),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
            iconSize: 22,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.notifications_none,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationCard(_notifications[index]);
                    },
                  ),
                ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final isRead = notif['isRead'] ?? false;
    final type = notif['type'] ?? 'info';

    IconData icon;
    Color color;

    switch (type) {
      case 'attendance':
        icon = Icons.fingerprint;
        color = Colors.blue;
        break;
      case 'leave':
        icon = Icons.event_busy;
        color = Colors.orange;
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          notif['title'] ?? 'Notification',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notif['message'] ?? ''),
            const SizedBox(height: 4),
            Text(
              AppDate.format(
                AppDate.tryParseUtc(notif['createdAt']),
                'MMM dd, yyyy hh:mm a',
              ),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: !isRead
            ? const Icon(Icons.circle, size: 12, color: Colors.blue)
            : null,
        onTap: () async {
          if (!isRead) {
            await ApiService.markNotificationAsRead(notif['id']);
            _loadNotifications();
          }
        },
      ),
    );
  }
}

// ============================================
// STOP TASK DIALOG
// ============================================
class StopTaskDialog extends StatefulWidget {
  const StopTaskDialog({super.key});

  @override
  _StopTaskDialogState createState() => _StopTaskDialogState();
}

class _StopTaskDialogState extends State<StopTaskDialog> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stop Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Add notes about your progress today (optional):'),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'What did you accomplish?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _notesController.text),
          child: const Text('Stop Task'),
        ),
      ],
    );
  }
}

// ============================================
// ATTENDANCE ACTION SCREEN (Check-in/out with Camera)
// ============================================
class AttendanceActionScreen extends StatefulWidget {
  final bool isCheckOut;
  final VoidCallback onSuccess;
  final bool captureOnly;
  final String? title;

  const AttendanceActionScreen({
    super.key,
    required this.isCheckOut,
    required this.onSuccess,
    this.captureOnly = false,
    this.title,
  });

  @override
  _AttendanceActionScreenState createState() => _AttendanceActionScreenState();
}

class _AttendanceActionScreenState extends State<AttendanceActionScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  Position? _currentPosition;
  late FaceDetector _faceDetector;
  bool _isDetecting = false;
  bool _faceCaptured = false;

  // LIVENESS DETECTION VARIABLES
  DateTime _lastDetectionTime = DateTime.now();
  int _blinkCount = 0;
  int _smileCount = 0;
  int _headTurnCount = 0;
  bool _wasEyesClosed = false;
  bool _wasSmiling = false;
  final List<double> _faceConfidences = [];
  final List<double> _headAnglesY = [];
  int _consecutiveGoodFrames = 0;
  String _statusMessage = 'Position your face in the circle';
  Color _statusColor = Colors.white;

  // RANDOM CHALLENGE SYSTEM
  String _currentChallenge = '';
  bool _challengeCompleted = false;
  final List<String> _challenges = ['blink', 'smile', 'turn_head'];

  // TEXTURE & LIGHTING ANALYSIS
  final List<double> _brightnessValues = [];
  int _staticFrameCount = 0;

  // POSITION TRACKING
  double _distanceFromCenter = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
    _selectRandomChallenge();
  }

  void _selectRandomChallenge() {
    final random = Random();
    final challenge = _challenges[random.nextInt(_challenges.length)];
    _currentChallenge = challenge;

    switch (challenge) {
      case 'blink':
        _statusMessage = 'Please blink once';
        break;
      case 'smile':
        _statusMessage = 'Please smile';
        break;
      case 'turn_head':
        _statusMessage = 'Slowly turn head left then right';
        break;
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isNotEmpty) {
        final frontCamera = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isIOS
              ? ImageFormatGroup.bgra8888
              : ImageFormatGroup.nv21,
        );

        await _cameraController!.initialize();

        _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableLandmarks: true,
            enableContours: false,
            enableClassification: true,
            enableTracking: true,
            minFaceSize: 0.15,
            performanceMode: FaceDetectorMode.accurate,
          ),
        );

        await _cameraController!.startImageStream(_processCameraImage);

        if (mounted) {
          setState(() => _isCameraInitialized = true);
        }
      }
    } catch (e) {
      print('❌ Camera error: $e');
      _showError('Camera initialization failed');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _faceCaptured) return;

    final now = DateTime.now();
    if (now.difference(_lastDetectionTime).inMilliseconds < 250) return;
    _lastDetectionTime = now;

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      final faces = await _faceDetector.processImage(inputImage);

      final brightness = _calculateBrightness(image);
      _brightnessValues.add(brightness);
      if (_brightnessValues.length > 10) _brightnessValues.removeAt(0);

      if (faces.isEmpty) {
        _updateStatus('No face detected', Colors.red);
        _resetLivenessData();
      } else if (faces.length > 1) {
        _updateStatus(
            'Multiple faces detected. Show only one face.', Colors.orange);
        _resetLivenessData();
      } else {
        await _performEnhancedLivenessChecks(faces.first, image);
      }
    } catch (e) {
      print('❌ Face detection error: $e');
    }

    _isDetecting = false;
  }

  Future<void> _performEnhancedLivenessChecks(
      Face face, CameraImage image) async {
    final boundingBox = face.boundingBox;
    final previewSize = _cameraController!.value.previewSize!;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const circleWidth = 280.0;
    const circleHeight = 350.0;
    final circleCenterX = screenWidth / 2;
    final circleCenterY = screenHeight / 2;

    final scaleX = screenWidth / previewSize.height;
    final scaleY = screenHeight / previewSize.width;

    final faceCenterX =
        boundingBox.left * scaleX + (boundingBox.width * scaleX) / 2;
    final faceCenterY =
        boundingBox.top * scaleY + (boundingBox.height * scaleY) / 2;
    final faceWidth = boundingBox.width * scaleX;
    final faceHeight = boundingBox.height * scaleY;

    final distanceFromCenter = ((faceCenterX - circleCenterX).abs() +
        (faceCenterY - circleCenterY).abs());
    _distanceFromCenter = distanceFromCenter;

    if (distanceFromCenter > 100) {
      _updateStatus('Center your face in the circle', Colors.orange);
      _resetLivenessData();
      return;
    }

    if (faceWidth < circleWidth * 0.5 || faceHeight < circleHeight * 0.4) {
      _updateStatus('Move closer to camera', Colors.orange);
      _resetLivenessData();
      return;
    }

    if (faceWidth > circleWidth * 1.2 || faceHeight > circleHeight * 1.2) {
      _updateStatus('Move back a little', Colors.red);
      _resetLivenessData();
      return;
    }

    final headEulerAngleY = face.headEulerAngleY ?? 0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0;

    if (_currentChallenge != 'turn_head') {
      if (headEulerAngleY.abs() > 20 || headEulerAngleZ.abs() > 20) {
        _updateStatus('Keep face straight', Colors.orange);
        _resetLivenessData();
        return;
      }
    }

    final leftEyeProb = face.leftEyeOpenProbability;
    final rightEyeProb = face.rightEyeOpenProbability;

    if (leftEyeProb == null || rightEyeProb == null) {
      _updateStatus('Eyes not detected clearly', Colors.orange);
      _resetLivenessData();
      return;
    }

    if (_brightnessValues.length >= 5) {
      final brightnessVariance = _calculateVariance(_brightnessValues);
      if (brightnessVariance < 0.5) {
        _staticFrameCount++;
        if (_staticFrameCount > 8) {
          _updateStatus('Too uniform. Please move slightly.', Colors.orange);
          _resetLivenessData();
          return;
        }
      } else {
        _staticFrameCount = 0;
      }
    }

    final imageWidth = previewSize.height;
    final faceSize =
        (boundingBox.width * boundingBox.height) / (imageWidth * imageWidth);

    _faceConfidences.add(faceSize);
    if (_faceConfidences.length > 8) _faceConfidences.removeAt(0);

    if (_faceConfidences.length >= 5) {
      final variance = _calculateVariance(_faceConfidences);
      if (variance < 0.000005) {
        _updateStatus('Too still. Please move slightly.', Colors.orange);
        _resetLivenessData();
        return;
      }
    }

    _headAnglesY.add(headEulerAngleY);
    if (_headAnglesY.length > 10) _headAnglesY.removeAt(0);

    await _validateChallenge(face, leftEyeProb, rightEyeProb, headEulerAngleY);

    final bothEyesOpen = leftEyeProb > 0.6 && rightEyeProb > 0.6;
    if (bothEyesOpen && _challengeCompleted) {
      _consecutiveGoodFrames++;
    } else if (!_challengeCompleted) {
      _consecutiveGoodFrames = 0;
    }

    if (_challengeCompleted && _consecutiveGoodFrames >= 3) {
      _updateStatus('✓ Verification complete! Capturing...', Colors.green);
      await Future.delayed(const Duration(milliseconds: 300));
      await _captureImage();
    }
  }

  Future<void> _validateChallenge(
    Face face,
    double leftEyeProb,
    double rightEyeProb,
    double headAngleY,
  ) async {
    if (_challengeCompleted) return;

    switch (_currentChallenge) {
      case 'blink':
        final bothEyesOpen = leftEyeProb > 0.6 && rightEyeProb > 0.6;
        final bothEyesClosed = leftEyeProb < 0.3 && rightEyeProb < 0.3;

        if (bothEyesClosed && !_wasEyesClosed) {
          _wasEyesClosed = true;
        } else if (bothEyesOpen && _wasEyesClosed) {
          _blinkCount++;
          _wasEyesClosed = false;
          if (_blinkCount >= 1) {
            _challengeCompleted = true;
            _updateStatus('Blink detected! Hold steady...', Colors.green);
          }
        }
        break;

      case 'smile':
        final smileProb = face.smilingProbability ?? 0;
        if (smileProb > 0.7 && !_wasSmiling) {
          _wasSmiling = true;
          _smileCount++;
          if (_smileCount >= 1) {
            _challengeCompleted = true;
            _updateStatus('✓ Smile detected! Hold steady...', Colors.green);
          }
        } else if (smileProb < 0.4) {
          _wasSmiling = false;
        }
        if (!_challengeCompleted) {
          _updateStatus('Please smile', Colors.yellow);
        }
        break;

      case 'turn_head':
        if (_headAnglesY.length >= 8) {
          final maxAngle = _headAnglesY.reduce((a, b) => a > b ? a : b);
          final minAngle = _headAnglesY.reduce((a, b) => a < b ? a : b);
          final range = maxAngle - minAngle;

          if (range > 30) {
            _headTurnCount++;
            if (_headTurnCount >= 1) {
              _challengeCompleted = true;
              _updateStatus(
                  'Head movement detected! Hold steady...', Colors.green);
            }
          } else {
            _updateStatus('Slowly turn head left then right', Colors.yellow);
          }
        }
        break;
    }
  }

  double _calculateBrightness(CameraImage image) {
    final bytes = image.planes.first.bytes;
    int sum = 0;
    for (int i = 0; i < bytes.length; i += 100) {
      sum += bytes[i];
    }
    return sum / (bytes.length / 100);
  }

  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean)).toList();
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  void _resetLivenessData() {
    _blinkCount = 0;
    _smileCount = 0;
    _headTurnCount = 0;
    _wasEyesClosed = false;
    _wasSmiling = false;
    _consecutiveGoodFrames = 0;
    _faceConfidences.clear();
    _headAnglesY.clear();
    _staticFrameCount = 0;
    _challengeCompleted = false;
  }

  void _updateStatus(String message, Color color) {
    if (mounted) {
      setState(() {
        _statusMessage = message;
        _statusColor = color;
      });
    }
  }

  InputImage _convertCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final format = Platform.isIOS
        ? InputImageFormat.bgra8888
        : InputImageFormat.nv21;

    final bytes = image.planes.first.bytes;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Location permission is required');
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      print(
          '📍 Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}');
    } catch (e) {
      print('❌ Location error: $e');
      _showError('Could not get location');
    }
  }

  Future<void> _captureImage() async {
    if (_faceCaptured) return;
    _faceCaptured = true;

    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    if (!widget.captureOnly && _currentPosition == null) {
      _showError('Location not available');
      _faceCaptured = false;
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _cameraController!.stopImageStream();
      final image = await _cameraController!.takePicture();

      if (widget.captureOnly) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        Navigator.pop(context, File(image.path));
        return;
      }

      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final employeeId = ApiService.empGuid;
      if (employeeId == null) {
        _showError('Employee ID not found');
        setState(() => _isProcessing = false);
        return;
      }

      Map<String, dynamic> result;

      if (widget.isCheckOut) {
        String address = await getAddress(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        result = await ApiService.checkOut(
          employeeId: employeeId,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          checkOutAddress: address,
          photoBase64: base64Image,
        );
      } else {
        String address = await getAddress(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        result = await ApiService.checkIn(
          employeeId: employeeId,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          checkInAddress: address,
          photoBase64: base64Image,
        );
      }

      setState(() => _isProcessing = false);

      if (result['success'] == true) {
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message'] ??
                  (widget.isCheckOut
                      ? 'Checked out successfully!'
                      : 'Checked in successfully!'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Something went wrong'),
            backgroundColor: Colors.red,
          ),
        );
        _isProcessing = false;
        _faceCaptured = false;
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      print('❌ Auto submit error: $e');
      _showError('Failed to submit: $e');
    }
  }

  Future<String> getAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        return '${place.name} ${place.thoroughfare} ${place.subLocality}, '
            '${place.locality} ${place.administrativeArea}, ${place.country}';
      }
      return 'No address found for these coordinates';
    } catch (e) {
      print('❌ Reverse geocoding error: $e');
      return 'Error getting location';
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title ?? (widget.isCheckOut ? 'Check Out' : 'Check In'),
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                Positioned.fill(child: CameraPreview(_cameraController!)),

                Center(
                  child: Container(
                    width: 280,
                    height: 350,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _statusColor, width: 4),
                    ),
                  ),
                ),

                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _statusColor.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _currentChallenge == 'blink'
                              ? Icons.remove_red_eye
                              : _currentChallenge == 'smile'
                                  ? Icons.sentiment_satisfied
                                  : Icons.sync,
                          color: _statusColor,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_challengeCompleted)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle,
                                    color: Colors.green, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Challenge completed!',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 160,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.security, color: Colors.blue, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'Security Checks',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildSecurityCheck(
                          'Position',
                          _distanceFromCenter > 0 &&
                              _distanceFromCenter <= 100,
                        ),
                        _buildSecurityCheck(
                            'Motion', _faceConfidences.length >= 3),
                        _buildSecurityCheck(
                            'Lighting', _brightnessValues.length >= 5),
                        _buildSecurityCheck('Challenge', _challengeCompleted),
                      ],
                    ),
                  ),
                ),

                if (_currentPosition != null)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.green, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Location: '
                            '${_currentPosition!.latitude.toStringAsFixed(4)}, '
                            '${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.8),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing attendance...',
                            style:
                                TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSecurityCheck(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: passed ? Colors.green : Colors.grey,
            size: 12,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: passed ? Colors.green : Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
