import 'dart:ui';
import 'dart:io' show Platform;
import 'package:attendance_app/adminscreen.dart';
import 'package:attendance_app/dashboard.dart';
import 'package:attendance_app/firebase_options.dart';
import 'package:attendance_app/leavescreen.dart';
import 'package:attendance_app/login.dart';
import 'package:attendance_app/managerpanel.dart';
import 'package:attendance_app/models/AttendanceRecord.dart';
import 'package:attendance_app/models/employee.dart';
import 'package:attendance_app/profile.dart';
import 'package:attendance_app/reportscreen.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/taskscreen.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
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
// CONFIGURATION - FOR ANDROID EMULATOR
// ============================================
const String API_BASE_URL =
    // 'http://10.0.2.2:5238/api'; //emmulator ip
    // 'http://103.104.192.247:1192' live ip
    'http://192.168.221.122:5238/api/'; // Android Emulator localhost
const String SIGNALR_URL = 'http://192.168.221.122:5238/attendanceHub';
//     'http://10.178.2.142:5238/api'; // Android Emulator localhost
// const String SIGNALR_URL = 'http://10.178.2.142:5238/attendanceHub';
//     'http://localhost:5238/api'; // Android Emulator localhost
// const String SIGNALR_URL = 'http://localhost:5238/attendanceHub';

// Use these for real device on same WiFi:
// const String API_BASE_URL = 'http://192.168.1.100:5000/api';  // Change to your PC IP
// const String SIGNALR_URL = 'http://192.168.1.100:5000/attendanceHub';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  await setupLocalNotifications(); // Re-initialize in background

  if (message.notification != null) {
    localNotifications.show(
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
      ),
    );
  }
}

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> setupLocalNotifications() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings = InitializationSettings(
    android: androidInit,
  );

  await localNotifications.initialize(initSettings);

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // MUST MATCH backend
    'High Importance Notifications',
    description: 'Used for important notifications',
    importance: Importance.max,
  );

  final androidPlugin = localNotifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  await androidPlugin?.createNotificationChannel(channel);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

if (!Platform.isIOS) {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
}

  // Initialize API Service
  await ApiService.init();

  // Initialize cameras
  final cameras = await availableCameras();

  await setupLocalNotifications();
 if (!Platform.isIOS) {
  await setupFCM();
}

  runApp(AttendanceApp(cameras: cameras));
}

/// ===============================
/// FCM Setup (Runs ONCE)
/// ===============================
Future<void> setupFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request permission
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // 🔹 Notification tap (app in background)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("📲 Notification clicked");
  });

  // Foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    try {
      print("🔥 MESSAGE RECEIVED");
      print(message.data);
      print(message.notification?.title);
      if (message.notification != null) {
        localNotifications.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // MUST MATCH channel id
              'High Importance Notifications',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
        print('🔔 Notification title: ${message.notification!.title}');
      }
    } catch (e) {
      print(' Local notification error: $e');
    }
  });

  // When user taps notification
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    print("🔄 FCM Token refreshed: $newToken");
    ApiService().sendTokenToBackend(newToken);
  });
}

// ============================================
// SIGNALR SERVICE
// ============================================
class SignalRService {
  HubConnection? _hubConnection;
  Function(Map<String, dynamic>)? onAttendanceUpdate;
  Function(Map<String, dynamic>)? onNotificationReceived; // NEW

  Future<void> connect() async {
    try {
      print('🔌 Connecting to SignalR...');

      // _hubConnection = HubConnectionBuilder().withUrl(SIGNALR_URL).build();
      var token = ApiService.authToken;

      if (token == null) {
        print(' Token is null');
      } else {
        _hubConnection = HubConnectionBuilder()
            .withUrl(
              SIGNALR_URL,
              options: HttpConnectionOptions(
                accessTokenFactory: () async => token,
              ),
            )
            .build();
      }

      // Listen for attendance updates
      _hubConnection!.on('ReceiveAttendanceUpdate', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          // print('📍 Real-time attendance update');
          final data = arguments[0] as Map<String, dynamic>;
          if (onAttendanceUpdate != null) {
            onAttendanceUpdate!(data);
          }
        }
      });

      // Listen for real-time notifications - NEW
      _hubConnection!.on('ReceiveNotification', (arguments) {
        if (arguments != null && arguments.isNotEmpty) {
          // print('🔔 Real-time notification received');
          final data = arguments[0] as Map<String, dynamic>;
          if (onNotificationReceived != null) {
            onNotificationReceived!(data);
          }
        }
      });

      await _hubConnection!.start();
      print(' SignalR connected');
    } catch (e) {
      print(' SignalR error: $e');
    }
  }

  Future<void> disconnect() async {
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      print('🔌 SignalR disconnected');
    }
  }
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================
// MAIN APP
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
        scaffoldBackgroundColor: Colors.grey[100],
      ),
      navigatorKey: navigatorKey,
      home: SplashScreen(),
    );
  }
}

// ============================================
// SPLASH SCREEN
// ============================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await Future.delayed(const Duration(seconds: 2));

    Widget nextScreen = LoginScreen();

    if (ApiService.authToken != null && ApiService.employeeId != null) {
      final response = await ApiService.getEmployeeById();

      if (response != null) {
        nextScreen = HomeScreen();
      }
    }

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint, size: 100, color: Colors.blue[700]),
            SizedBox(height: 20),
            Text(
              'Attendance System',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
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
  //GEt Employee info
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
       if (!Platform.isIOS) {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await ApiService().sendTokenToBackend(token);
  }
}
      } else {
        _showError(
          'Failed to send device registration request. Please try again later.',
        );
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
      // print('📍 Attendance update: $data');
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
      // print('🔔 Notification: ${data['title']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['title'] ?? 'Notification',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(data['message'] ?? ''),
            ],
          ),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 4),
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _showRequestSentDialogBlur() {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "",
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AlertDialog(
            title: const Text("Request Sent"),
            content: const Text(
              "Your request has been sent to admin.\n\nPlease wait for approval.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("OK"),
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
      barrierLabel: "",
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AlertDialog(
            title: const Text("New Device"),
            content: const Text(
              "This device is not registered.\n\nDo you want to request registration?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                // Navigator.pushReplacement(
                //   context,
                //   MaterialPageRoute(builder: (context) => LoginScreen()),
                // ),
                child: const Text("No"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Yes"),
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

      print("Device registration request sent to backend");
      if (result == true) {
        print("Device registration request successful");
        return true;
      } else {
        print("Device registration request failed");
        return false;
      }
    } catch (e) {
      print("Error sending request: $e");
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

    return [
      DashboardScreen(),
      TasksScreen(),
      AttendanceHistoryScreen(),
      LeaveScreen(),
      // Employeereport(),
      ReportsScreen(),
      if (role.contains('admin')) Adminscreen(),
      if (role.contains('manager')) ManagerPanel(),
      ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (ApiService.isFirstTimeLogin) {
      return Scaffold(body: Container(color: Colors.black.withOpacity(0.2)));
    }
    final role = employee?.role.map((r) => r.toLowerCase()).toList() ?? [];
    final isAdmin = role.contains('admin');
    final isManager = role.contains('manager');

    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[700],
        unselectedItemColor: Colors.grey,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.task_outlined),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'History',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.event_busy), label: 'Leave'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_chart_outlined),
            label: 'Reports',
          ),
          // Conditionally show Admin tab for admin users
          if (isAdmin)
            BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_outlined),
              label: 'Admin',
            ),
          // Conditionally show Manager tab for manager users
          if (isManager)
            BottomNavigationBarItem(
              icon: Icon(Icons.supervisor_account_outlined),
              label: 'Manager',
            ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ============================================
// NEW NOTIFICATIONS SCREEN
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
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh_outlined),
            onPressed: _loadNotifications,
            tooltip: 'Refresh',
            iconSize: 22,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
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
                padding: EdgeInsets.all(16),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notif = _notifications[index];
                  return _buildNotificationCard(notif);
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
      margin: EdgeInsets.only(bottom: 12),
      color: isRead ? Colors.white : Colors.blue[50],
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(12),
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
            SizedBox(height: 4),
            Text(notif['message'] ?? ''),
            SizedBox(height: 4),
            Text(
              DateFormat(
                'MMM dd, yyyy hh:mm a',
              ).format(DateTime.parse(notif['createdAt'])),
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: !isRead
            ? Icon(Icons.circle, size: 12, color: Colors.blue)
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
// KEY FIXES APPLIED:
// ============================================
// 1. Fixed undefined 'employeeId' and 'employee' variables in DashboardScreen
// 2. Added missing TasksScreen widget
// 3. Fixed variable scope issues
// 4. Improved error handling
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
      title: Text('Stop Task'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add notes about your progress today (optional):'),
          SizedBox(height: 16),
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
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _notesController.text);
          },
          child: Text('Stop Task'),
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

  const AttendanceActionScreen({
    super.key,
    required this.isCheckOut,
    required this.onSuccess,
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

  // 🔥 ENHANCED LIVENESS DETECTION VARIABLES
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

  // 🎯 RANDOM CHALLENGE SYSTEM
  String _currentChallenge = '';
  bool _challengeCompleted = false;
  final List<String> _challenges = ['blink', 'smile', 'turn_head'];

  // 📊 TEXTURE & LIGHTING ANALYSIS
  final List<double> _brightnessValues = [];
  int _staticFrameCount = 0;

  // 📍 POSITION TRACKING
  double _distanceFromCenter = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _getCurrentLocation();
    _selectRandomChallenge();
  }

  // 🎲 Select random challenge for user
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
          imageFormatGroup: ImageFormatGroup.nv21,
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
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print(' Camera error: $e');
      _showError('Camera initialization failed');
    }
  }

  // 🔥 ENHANCED FACE DETECTION WITH MULTI-LAYER SECURITY
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _faceCaptured) return;

    final now = DateTime.now();
    if (now.difference(_lastDetectionTime).inMilliseconds < 250) return;
    _lastDetectionTime = now;

    _isDetecting = true;

    try {
      final inputImage = _convertCameraImage(image);
      final faces = await _faceDetector.processImage(inputImage);

      // 🔍 TEXTURE ANALYSIS: Calculate average brightness
      final brightness = _calculateBrightness(image);
      _brightnessValues.add(brightness);
      if (_brightnessValues.length > 10) {
        _brightnessValues.removeAt(0);
      }

      if (faces.isEmpty) {
        _updateStatus('No face detected', Colors.red);
        _resetLivenessData();
      } else if (faces.length > 1) {
        _updateStatus(
          'Multiple faces detected. Show only one face.',
          Colors.orange,
        );
        _resetLivenessData();
      } else {
        final face = faces.first;
        await _performEnhancedLivenessChecks(face, image);
      }
    } catch (e) {
      print(' Face detection error: $e');
    }

    _isDetecting = false;
  }

  // 🔥 MULTI-LAYER ENHANCED LIVENESS DETECTION
  Future<void> _performEnhancedLivenessChecks(
    Face face,
    CameraImage image,
  ) async {
    //  CHECK 1: Face must be inside the circle guide
    final boundingBox = face.boundingBox;
    final previewSize = _cameraController!.value.previewSize!;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final circleWidth = 280.0;
    final circleHeight = 350.0;
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

    final distanceFromCenter =
        ((faceCenterX - circleCenterX).abs() +
        (faceCenterY - circleCenterY).abs());
    _distanceFromCenter = distanceFromCenter; // Store for UI indicator

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

    //  CHECK 2: Head Pose (must be relatively straight)
    final headEulerAngleY = face.headEulerAngleY ?? 0;
    final headEulerAngleZ = face.headEulerAngleZ ?? 0;

    // For turn_head challenge, allow more movement
    if (_currentChallenge != 'turn_head') {
      if (headEulerAngleY.abs() > 20 || headEulerAngleZ.abs() > 20) {
        _updateStatus('Keep face straight', Colors.orange);
        _resetLivenessData();
        return;
      }
    }

    //  CHECK 3: Eye Detection
    final leftEyeProb = face.leftEyeOpenProbability;
    final rightEyeProb = face.rightEyeOpenProbability;

    if (leftEyeProb == null || rightEyeProb == null) {
      _updateStatus('Eyes not detected clearly', Colors.orange);
      _resetLivenessData();
      return;
    }

    //  CHECK 4: LIGHTING VARIATION ANALYSIS (Anti-Photo Spoofing)
    if (_brightnessValues.length >= 5) {
      final brightnessVariance = _calculateVariance(_brightnessValues);

      // Photos have very uniform lighting, real faces have natural variation
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

    //  CHECK 5: ENHANCED MOTION DETECTION
    final imageWidth = previewSize.height;
    final faceSize =
        (boundingBox.width * boundingBox.height) / (imageWidth * imageWidth);

    _faceConfidences.add(faceSize);
    if (_faceConfidences.length > 8) {
      _faceConfidences.removeAt(0);
    }

    if (_faceConfidences.length >= 5) {
      final variance = _calculateVariance(_faceConfidences);
      if (variance < 0.000005) {
        _updateStatus('Too still. Please move slightly.', Colors.orange);
        _resetLivenessData();
        return;
      }
    }

    //  CHECK 6: HEAD MOVEMENT TRACKING (for turn_head challenge)
    _headAnglesY.add(headEulerAngleY);
    if (_headAnglesY.length > 10) {
      _headAnglesY.removeAt(0);
    }

    //  CHECK 7: CHALLENGE-RESPONSE VALIDATION
    await _validateChallenge(face, leftEyeProb, rightEyeProb, headEulerAngleY);

    //  CHECK 8: Consecutive good frames
    final bothEyesOpen = leftEyeProb > 0.6 && rightEyeProb > 0.6;
    if (bothEyesOpen && _challengeCompleted) {
      _consecutiveGoodFrames++;
    } else if (!_challengeCompleted) {
      _consecutiveGoodFrames = 0;
    }

    // 🎯 FINAL DECISION: All security checks passed
    if (_challengeCompleted && _consecutiveGoodFrames >= 3) {
      _updateStatus('✓ Verification complete! Capturing...', Colors.green);
      await Future.delayed(Duration(milliseconds: 300));
      await _captureImage();
    }
  }

  // VALIDATE RANDOM CHALLENGE
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
          print('Blink detected! Count: $_blinkCount');

          if (_blinkCount >= 1) {
            _challengeCompleted = true;
            _updateStatus('Blink detected! Hold steady...', Colors.green);
          } else {
            _updateStatus('Please blink once', Colors.yellow);
          }
        }
        break;

      case 'smile':
        final smileProb = face.smilingProbability ?? 0;

        if (smileProb > 0.7 && !_wasSmiling) {
          _wasSmiling = true;
          _smileCount++;
          print('Smile detected! Count: $_smileCount');

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

          // User must turn head at least 30 degrees total (left and right)
          if (range > 30) {
            _headTurnCount++;
            print('Head turn detected! Range: $range degrees');

            if (_headTurnCount >= 1) {
              _challengeCompleted = true;
              _updateStatus(
                'Head movement detected! Hold steady...',
                Colors.green,
              );
            }
          } else {
            _updateStatus('Slowly turn head left then right', Colors.yellow);
          }
        }
        break;
    }
  }

  // 🔧 TEXTURE ANALYSIS: Calculate average brightness
  double _calculateBrightness(CameraImage image) {
    final bytes = image.planes.first.bytes;
    int sum = 0;

    // Sample every 100th pixel for performance
    for (int i = 0; i < bytes.length; i += 100) {
      sum += bytes[i];
    }

    return sum / (bytes.length / 100);
  }

  // 🔧 Helper: Calculate variance
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => (v - mean) * (v - mean)).toList();
    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  // 🔧 Helper: Reset liveness data
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

  // 🔧 Helper: Update status message
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

    final bytes = image.planes.first.bytes;

    final inputImage = InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );

    return inputImage;
  }

  Future<void> _closeCameraAndExit() async {
    try {
      _isDetecting = false;

      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }

      await _cameraController?.dispose();
      _cameraController = null;
      print("camera exist method ");
      await _faceDetector.close();
    } catch (e) {
      print(' Camera cleanup error: $e');
    }
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
        '📍 Location: ${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
      );
    } catch (e) {
      print(' Location error: $e');
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

    if (_currentPosition == null) {
      _showError('Location not available');
      _faceCaptured = false;
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _cameraController!.stopImageStream();

      final image = await _cameraController!.takePicture();
      final imageBytes = await image.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      final employeeId = ApiService.employeeId;
      if (employeeId == null) {
        _showError('Employee ID not found');
        setState(() => _isProcessing = false);
        return;
      }

      Map<String, dynamic> result;


      if (widget.isCheckOut) {

        String address = await getAddress(_currentPosition!.latitude, _currentPosition!.longitude);
        
        result = await ApiService.checkOut(
          employeeId: employeeId,
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          checkOutAddress: address,
          photoBase64: base64Image,
        );
      } else {
        String address = await getAddress(_currentPosition!.latitude, _currentPosition!.longitude);
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
        //  Face recognition / backend validation failed
        // await _restartFaceDetection(
        //   message: result['error'] ?? 'Face not recognized. Try again.',
        // );
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error']),
            backgroundColor: Colors.green,
          ),
        );
        _isProcessing = false;
        _faceCaptured = false;
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      print(' Auto submit error: $e');
      _showError('Failed to submit: $e');
    }
  }

  Future<String> getAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "${place.name} ${place.thoroughfare} ${place.subLocality}, ${place.locality} ${place.administrativeArea}, ${place.country}";
        return address;
      }
      
      return "No address found for these coordinates"; 

    } catch (e) {
      print("Reverse geocoding error: $e");
      return "Error getting location";
    }
  }

  Future<void> _restartFaceDetection({String? message}) async {
    // Reset flags
    _faceCaptured = false;
    _isProcessing = false;
    _isDetecting = false;
    _challengeCompleted = false;

    _resetLivenessData();

    if (message != null) {
      _updateStatus(message, Colors.red);
    }

    // Restart camera stream if needed
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      await _cameraController!.startImageStream(_processCameraImage);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
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
        title: Text(widget.isCheckOut ? 'Check Out' : 'Check In'),
        backgroundColor: Colors.black,
      ),
      body: _isCameraInitialized
          ? Stack(
              children: [
                // Camera Preview
                Positioned.fill(child: CameraPreview(_cameraController!)),

                // Face Guide Oval
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

                // Status Instructions
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    margin: EdgeInsets.symmetric(horizontal: 24),
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
                        // Challenge Icon
                        Icon(
                          _currentChallenge == 'blink'
                              ? Icons.remove_red_eye
                              : _currentChallenge == 'smile'
                              ? Icons.sentiment_satisfied
                              : Icons.sync,
                          color: _statusColor,
                          size: 32,
                        ),
                        SizedBox(height: 8),

                        // Status Message
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        // Challenge Completion Indicator
                        if (_challengeCompleted)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 18,
                                ),
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

                // Security Indicators
                Positioned(
                  top: 160,
                  left: 20,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
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
                        SizedBox(height: 6),
                        _buildSecurityCheck(
                          'Position',
                          _distanceFromCenter > 0 && _distanceFromCenter <= 100,
                        ),
                        _buildSecurityCheck(
                          'Motion',
                          _faceConfidences.length >= 3,
                        ),
                        _buildSecurityCheck(
                          'Lighting',
                          _brightnessValues.length >= 5,
                        ),
                        _buildSecurityCheck('Challenge', _challengeCompleted),
                      ],
                    ),
                  ),
                ),

                // Location Info
                if (_currentPosition != null)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      margin: EdgeInsets.symmetric(horizontal: 40),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Location: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Processing Overlay
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.8),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Processing attendance...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
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

  // Helper: Build security check indicator
  Widget _buildSecurityCheck(String label, bool passed) {
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: passed ? Colors.green : Colors.grey,
            size: 12,
          ),
          SizedBox(width: 6),
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

// ============================================
// ATTENDANCE HISTORY SCREEN
// ============================================
class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  _AttendanceHistoryScreenState createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  String formatHoursToHHMM(String hoursString) {
    try {
      final time = double.parse(hoursString);
      final totalMinutes = (time * 60).round();
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return '${hours}h ${minutes}m';
    } catch (e) {
      return '00:00';
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    final employeeId = ApiService.employeeId;
    if (employeeId != null) {
      final records = await ApiService.getAttendanceHistory(employeeId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance History',
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
            icon: Icon(Icons.refresh_outlined),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
            iconSize: 22,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No attendance records',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadHistory,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _records.length,
                itemBuilder: (context, index) {
                  final record = _records[index];
                  return _buildRecordCard(record);
                },
              ),
            ),
    );
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat(
                    'EEEE, MMM d, yyyy',
                  ).format(record.attendanceDate!.toLocal()),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: record.status == 'Present'
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.status?.toUpperCase() ?? '',
                    style: TextStyle(
                      color: record.status == 'Present'
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.login, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Check-in:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        record.checkInTime != null
                            ? DateFormat(
                                'hh:mm a',
                              ).format(record.checkInTime!.toLocal())
                            : '--:--',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.logout, size: 16, color: Colors.red),
                          SizedBox(width: 4),
                          Text(
                            'Check-out:',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        record.checkOutTime != null
                            ? DateFormat(
                                'hh:mm a',
                              ).format(record.checkOutTime!.toLocal())
                            : '--:--',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (record.totalHours != "") ...[
              Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.blue),
                      SizedBox(width: 4),
                      Text(
                        'Total: ${formatHoursToHHMM(record.totalHours ?? '')}',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if ((record.location ?? '').isNotEmpty)
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          record.location ?? '',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            if ((record.checkInSource ?? '').isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    record.checkInSource == 'zkteco'
                        ? Icons.fingerprint
                        : Icons.phone_android,
                    size: 14,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Source: ${(record.checkInSource?.toLowerCase() == 'zkteco' ? record.deviceName : record.checkInSource ?? 'N/A')}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
