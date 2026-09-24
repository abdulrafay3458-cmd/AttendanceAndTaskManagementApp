import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:attendance_app/main.dart';
import 'package:attendance_app/models/AttendanceRecord.dart';
import 'package:attendance_app/models/applyimage.dart';
import 'package:attendance_app/models/chart.dart';
import 'package:attendance_app/models/dayWise.dart';
import 'package:attendance_app/models/pendingTasks.dart';
import 'package:attendance_app/models/prevDateData.dart';
import 'package:attendance_app/services/imageregistration.dart';
import 'package:attendance_app/services/taskmodel.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/taskdetail.dart';
import 'package:attendance_app/taskscreen.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:slide_to_act/slide_to_act.dart';
import 'package:geolocator/geolocator.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTime? dueDateTime;
  List<PendingTask> _pendingTasks = [];
  bool _isLoadingTasks = true;
  DateTime? _previousValidDate;
  TaskSummaryResponse? _taskSummary;
  bool _dialogShown = false;
  AttendanceRecord? _todayAttendance;
  List<TaskModel> _activeTasks = [];
  bool _isLoading = true;
  bool _isLeave = false;
  String _currentTime = '';
  Timer? _timer;
  Timer? _realtimeTimer;
  bool _isRealtimeUpdating = false;

  // Dates (Current, Range Date)
  DateTime _selectedDate = DateTime.now();
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now();
  bool checkProg = false;

  // Profile Image
  ImageProvider? _profileImageProvider;
  bool _isCheckingImageStatus = false;
  bool _hasImageError = false;
  
  // Previous Day Data List
  PreviousDateData? _previousDateData;
  Daywise? _standardHours;
  bool _isHoliday = false;

  // Standar Hour Circular Stats
  String _realTimeWorkingHours = "0h 0m";
  String _realTimeOvertime = "0h 0m";
  double _realTimeProgress = 0.0;
  Color _progressColor = const Color(0xFF3B73C6);

  //Image Registration
  bool _isUploading = false;
  bool isApproved = false;
  String? _pendingApprovalImage;
  Chart? _chart;
  String _selectedType = "weekly";
  final List<String> _types = ["weekly", "monthly", "yearly"];

void _loadPendingTasks() async {
  try {
     final employee = ApiService.currentEmployee?.employeeId;
    final tasks = await ApiService.fetchPendingTasks(employee);
    setState(() {
      _pendingTasks = tasks;
      _isLoadingTasks = false;
    });
  } catch (e) {
    print("Error fetching tasks: $e");
    setState(() => _isLoadingTasks = false);
  }
}

  Future<void> _captureImage() async {
    await ProfileImageService.openFrontCamera(
      context: context,
      onImageCaptured: (file) async {
        setState(() {
          _isUploading = true;
        });

        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);

        final success = await ApiService.getNewProfileRequest(
          ApplyImageModel(
            employeeCode: ApiService.currentEmployee!.employeeId,
            faceImage: base64Image,
            companyCode: ApiService.currentEmployee!.companyCode,
          ),
        );

        if (success['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image sent for approval'),
              backgroundColor: Colors.green,
            ),
          );

          await checkImageApprovalStatus();
          _loadProfileImage();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Image approval failed.'),
              backgroundColor: Colors.red,
            ),
          );
        }

        setState(() {
          _isUploading = false;
        });
      },
    );
  }

  // Check image is missing or not
  bool isFaceImageMissing =
      ApiService.currentEmployee?.faceImageBase64 == null ||
      ApiService.currentEmployee!.faceImageBase64!.isEmpty;

  bool needToRegisterDevice =
      ApiService.currentEmployee?.isDeviceRegistered == true ? false : true;
  // ApiService.currentEmployee?.isDeviceRegistered != true;

  DateTime? _getCheckInDateTime() {
    if (!_isTodaySelected()) {
      return _previousDateData?.checkIn;
    }

    return _todayAttendance?.checkInTime;
  }

  bool _isUserCheckedIn() {
    final checkInTime = _getCheckInDateTime();
    if (checkInTime == null) return false;

    if (_isTodaySelected()) {
      return _todayAttendance?.checkOutTime == null;
    }

    return true;
  }

  void _startRealTimeUpdates() {
    
    _realtimeTimer?.cancel();
    _updateRealTimeData();
    
    _realtimeTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isTodaySelected() && _isUserCheckedIn()) {
        _updateRealTimeData();
      } else {
        timer.cancel();
        _realtimeTimer = null;
      }
    });
  }

  @override
  void initState() {
    _loadPendingTasks();

    super.initState();
    _initializeProfileImage();

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (!_dialogShown) {
    //     _dialogShown = true;
    //     if (isFaceImageMissing && !needToRegisterDevice && !isApproved) {
    //       _showImageRegistrationDialog(context);
    //     }
    //   }
    // });

    _loadData().then((_) {
      if (_isTodaySelected() && _isUserCheckedIn()) {
        _startRealTimeUpdates();
      }
    });

    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
  }

  String _formatTotalHours(double? hours) {
    if (hours == null) return '0h 0m';

    final totalMinutes = (hours * 60).round();
    final hoursPart = totalMinutes ~/ 60;
    final minutesPart = totalMinutes % 60;

    return '${hoursPart}h ${minutesPart}m';
  }

  Future<void> _initializeProfileImage() async {
    await checkImageApprovalStatus();
    _loadProfileImage();
  }

  Future<void> checkImageApprovalStatus() async {
    if (_isCheckingImageStatus) return;

    setState(() {
      _isCheckingImageStatus = true;
    });

    try {
      final employee = ApiService.currentEmployee;
      if (employee == null) return;

      final status = await ApiService.getImageApprovalStatus(
        employee.employeeId,
      );

      setState(() {
        isApproved = status;
      });
    } catch (e) {
      print('Error checking approval status: $e');
    } finally {
      setState(() {
        _isCheckingImageStatus = false;
      });
    }
  }

  void _loadProfileImage() {
    final employee = ApiService.currentEmployee;
    if (employee == null) return;

    setState(() {
      _profileImageProvider = null;
      _hasImageError = false;
    });

    if (isApproved == true &&
        employee.faceImageBase64 != null &&
        employee.faceImageBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(employee.faceImageBase64!.trim());
        final imageProvider = MemoryImage(bytes);

        imageProvider
            .resolve(ImageConfiguration.empty)
            .addListener(
              ImageStreamListener(
                (info, synchronousCall) {
                  if (mounted) {
                    setState(() {
                      _profileImageProvider = imageProvider;
                      _hasImageError = false;
                    });
                  }
                },
                onError: (exception, stackTrace) {
                  if (mounted) {
                    setState(() {
                      _profileImageProvider = null;
                      _hasImageError = true;
                    });
                  }
                },
              ),
            );
      } catch (e) {
        setState(() {
          _profileImageProvider = null;
          _hasImageError = true;
        });
      }
    }
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: SizeConfig.w(9.5),
          backgroundColor: Colors.white,
          backgroundImage: _profileImageProvider,
          child: _shouldShowCameraIcon()
              ? Icon(
                  Icons.person,
                  size: SizeConfig.w(10),
                  color: Colors.blue[700],
                )
              : (_profileImageProvider == null && !_hasImageError)
              ? Icon(Icons.person, size: SizeConfig.w(6), color: Colors.grey)
              : null,
        ),

        if (_isCheckingImageStatus || (isApproved == false && !_hasImageError))
          Positioned(
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _shouldShowCameraIcon() {
    if (_isCheckingImageStatus) return false;
    if (_profileImageProvider != null) return false;
    if (_pendingApprovalImage != null) return false;
    return !isApproved || _hasImageError;
  }

  void _showImageRegistrationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Image Registration..',
            style: TextStyle(
              fontSize: SizeConfig.f(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Register your face image to enable facial attendance.',
            style: TextStyle(
              fontSize: SizeConfig.f(14),
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, DashboardScreen());
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: SizeConfig.f(12),
                  color: Colors.black87,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _captureImage();
              },
              child: Text(
                'Capture Image',
                style: TextStyle(
                  fontSize: SizeConfig.f(12),
                  color: Colors.blue[700],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    await ApiService.getEmployeeById();
    setState(() {
      needToRegisterDevice =
          ApiService.currentEmployee?.isDeviceRegistered == true ? false : true;
    });

    final employeeId = ApiService.employeeId;
    final companyCode = ApiService.currentEmployee?.companyCode;
    final chart = await ApiService.chart(
      employeeId: employeeId!,
      endDate: DateTime.now(),
      dateTime: DateTime.now(),
    );

    try {
      Daywise? result;
      try {
        if (employeeId != null && employeeId.isNotEmpty) {
          result = await ApiService.standardHour(employeeId, DateTime.now());
        }
      } catch (e) {
        print("Error in getStandardHour: $e");
      }

      _taskSummary = await ApiService.taskSummary();

      if (employeeId != null) {
        final isHoliday = await ApiService.isHoliday(employeeId, _selectedDate);
        final isLeave = await ApiService.isOnLeave(employeeId, companyCode);
        final attendance = await ApiService.getTodayAttendance(employeeId);
        final loadchart = await ApiService.chart(employeeId: employeeId,
                                             endDate: _selectedEndDate,
                                             dateTime: _selectedStartDate, 
                                           );
        final tasks = await ApiService.getActiveTasks(employeeId);
        if (tasks.isNotEmpty) {
          calculateOffset(tasks.first.serverNow);
        } else {
          // No active tasks
          _serverOffset = Duration.zero;
        }
        final filteredTasks = tasks
            .where((task) => task.status == 'in_progress')
            .toList();

        setState(() {
          _isLeave = isLeave;
          _chart = loadchart;
          _isHoliday = isHoliday;
          _standardHours = result;
          _todayAttendance = attendance;
          _activeTasks = filteredTasks;
          _isLoading = false;
        });
        _initializeProfileImage();
        _updateRealTimeData();
        _handleRealtimeTimer();
      }
    } catch (e) {
      print("Error loading data: $e");
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _handleRealtimeTimer() {
    if (_isTodaySelected() && _isUserCheckedIn()) {
      if (_realtimeTimer == null || !_realtimeTimer!.isActive) {
        _startRealTimeUpdates();
      }
    } else {
      _realtimeTimer?.cancel();
      _realtimeTimer = null;
    }
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('hh:mm:ss a').format(DateTime.now());
    });
  }

  bool _isTodaySelected() {
    final today = DateTime.now();
    return _selectedDate.year == today.year &&
        _selectedDate.month == today.month &&
        _selectedDate.day == today.day;
  }
// bool _canMarkManualAttendance() {
//   final today = DateTime.now();

//   final currentDate = DateTime(today.year, today.month, today.day);
//   final selected = DateTime(
//     _selectedDate.year,
//     _selectedDate.month,
//     _selectedDate.day,
//   );

//   bool isPastDate = selected.isBefore(currentDate);

//   print("Is Leave: ${_previousDateData}");
//   bool isLeaveDay =
//       _previousDateData?.isLeave == true || _isLeave == true;

//   return isPastDate && !isLeaveDay;
// } 

  Future<void> _stopTaskFirst() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Check Out Failed',
            style: TextStyle(
              fontSize: SizeConfig.f(16),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Please stop the running task first.',
            style: TextStyle(
              fontSize: SizeConfig.f(14),
              fontWeight: FontWeight.w400,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, DashboardScreen());
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: SizeConfig.f(12),
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        );
      },
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

  void registerDevice() async {
    setState(() => _isLoading = true);
    final result = await ApiService.requestToRegisterUserDevice();
    if (result) {
      setState(() {
        ApiService.currentEmployee?.AppliedDeviceRegistration = true;
      });
      setState(() => _isLoading = false);
      await _showRequestSentDialogBlur();
    } else {
      setState(() => _isLoading = false);
      _showError(
        'Failed to send device registration request. Please try again later.',
      );
    }
  }

  bool get showRegisterContainer =>
      ApiService.currentEmployee?.isDeviceRegistered != true &&
      ApiService.currentEmployee?.anyDeviceRegistered != true &&
      ApiService.currentEmployee?.AppliedDeviceRegistration != true;

  bool get showAlreadyRegisteredMessage =>
      (ApiService.currentEmployee?.isDeviceRegistered != true &&
          ApiService.currentEmployee?.anyDeviceRegistered == true) ||
      ApiService.currentEmployee?.AppliedDeviceRegistration == true;

  Future<void> _handleAttendance() async {
    final employeeId = ApiService.employeeId;
    if (employeeId == null) return;

    final isCheckOut = _todayAttendance?.checkInTime != null;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceActionScreen(
          isCheckOut: isCheckOut,
          onSuccess: () {
            _loadData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    SizeConfig.init(context);
    final employee = ApiService.currentEmployee;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dashboard',
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
            onPressed: _loadData,
            tooltip: 'Refresh',
            iconSize: 22,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(SizeConfig.w(4)),
                      child: Column(
                        children: [
                          if (employee != null) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: SizeConfig.w(4),
                                vertical: SizeConfig.w(6),
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(
                                  SizeConfig.w(3),
                                ),
                              ),

                              child: Row(
                                children: [
                                  _buildProfileImage(),
                                  SizedBox(
                                    width: SizeConfig.w(7),
                                    height: SizeConfig.h(18),
                                    child: VerticalDivider(
                                      color: Colors.white,
                                      thickness: 1,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          employee.name.toUpperCase(),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: SizeConfig.f(16),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: SizeConfig.h(0.5)),
                                        Text(
                                          '${employee.designation}',
                                          style: TextStyle(color: Colors.white),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: SizeConfig.h(1)),
                                        Divider(
                                          color: Colors.white,
                                          thickness: 1,
                                        ),
                                        SizedBox(height: SizeConfig.h(1)),

                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text.rich(
                                                  TextSpan(
                                                    children: [
                                                      TextSpan(
                                                        text: 'Check In: ',
                                                        style: TextStyle(
                                                          fontSize:
                                                              SizeConfig.f(12),
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      TextSpan(
                                                        text: _getCheckInTime(),
                                                        style: TextStyle(
                                                          fontSize:
                                                              SizeConfig.f(12),
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Spacer(),
                                                if (_getCheckInTime() !=
                                                    '--:--')
                                                  Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal:
                                                              SizeConfig.w(3),
                                                          vertical:
                                                              SizeConfig.h(1),
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          (_standardHours
                                                                  ?.IsLate ??
                                                              false)
                                                          ? Colors.red
                                                          : Colors.green,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      (_standardHours?.IsLate ??
                                                              false)
                                                          ? 'Late'
                                                          : 'On Time',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: SizeConfig.f(
                                                          10,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: 'Check Out: ',
                                                    style: TextStyle(
                                                      fontSize: SizeConfig.f(
                                                        12,
                                                      ),
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.normal,
                                                    ),
                                                  ),
                                                  TextSpan(
                                                    text: _getCheckOutTime(),
                                                    style: TextStyle(
                                                      fontSize: SizeConfig.f(
                                                        12,
                                                      ),
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    SizeConfig.w(8),
                                  ),
                                  child: Image.asset(
                                    'assets/img/man_pic.jpg',
                                    width: SizeConfig.w(15),
                                    height: SizeConfig.h(7),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                SizedBox(width: SizeConfig.w(4)),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "EMPLOYEE",
                                        style: TextStyle(
                                          color: Color.fromARGB(255, 0, 0, 0),
                                          fontSize: SizeConfig.f(16),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: SizeConfig.h(0.5)),
                                      Text(
                                        "Designation • Department",
                                        style: TextStyle(
                                          color: Color.fromARGB(
                                            255,
                                            46,
                                            46,
                                            46,
                                          ),
                                          fontSize: SizeConfig.f(12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: SizeConfig.w(2)),
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.notifications_none,
                                    size: SizeConfig.f(24),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: SizeConfig.h(2)),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: showRegisterContainer
                                ? Container(
                                    key: const ValueKey("register"),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFF59E0B),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.warning_amber_rounded,
                                          color: Color(0xFFF59E0B),
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                "Device Not Registered",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Color(0xFF7C2D12),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              const Text(
                                                "Register this device to continue using in-app check-in and check-out.",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 10),

                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: ElevatedButton(
                                                  onPressed: registerDevice,
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFFF59E0B),
                                                    foregroundColor:
                                                        Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 10,
                                                        ),
                                                  ),
                                                  child: const Text(
                                                    "Register Device",
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : showAlreadyRegisteredMessage
                                ? Container(
                                    key: const ValueKey("pending"),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFF10B981),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.hourglass_top_rounded,
                                          color: Color(0xFF10B981),
                                          size: 26,
                                        ),
                                        const SizedBox(width: 12),

                                        const Expanded(
                                          child: Text(
                                            "Your device registration request has been sent and is pending admin approval.",
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox(),
                          ),

                          // DATE TIMELINE
                          Padding(
                            padding: EdgeInsets.all(0),
                            child: EasyDateTimeLine(
                              initialDate: _selectedDate.isAfter(DateTime.now()) 
                                  ? DateTime.now() 
                                  : _selectedDate,
                              onDateChange: (date) async {
                                
                                // Check if selected date is in the future
                                final now = DateTime.now();
                                final selectedDate = DateTime(date.year, date.month, date.day);
                                final currentDate = DateTime(now.year, now.month, now.day);
                                
                                // Future date selected - show message and don't proceed
                                if (selectedDate.isAfter(currentDate)) {
                                  setState(() {
                                    _selectedDate = selectedDate;
                                  });
                                  return;
                                }
                                
                                // Update previous valid date
                                _previousValidDate = selectedDate;
                                
                                setState(() {
                                  _selectedDate = date;
                                  _isLoading = true;
                                });

                                // Cancel real-time timer when changing dates
                                _realtimeTimer?.cancel();
                                _realtimeTimer = null;

                                try {
                                  String formattedDate = DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(date);
                                  final empId = employee?.employeeId;

                                  if (empId == null || empId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Employee ID is required',
                                        ),
                                      ),
                                    );
                                    return;
                                  }

                                  final data = await ApiService.getDataForDate(formattedDate, empId);
                                  final holidayResult = await ApiService.isHoliday(empId, _selectedDate);
                                  final result = await ApiService.standardHour(empId, date);
                                  
                                  int doneCount = 0;
                                  int inProgressCount = 0;

                                  for (var item in data.taskList) {
                                    if (item.taskStatus.toLowerCase() ==
                                        'completed') {
                                      doneCount++;
                                    } else {
                                      inProgressCount++;
                                    }
                                  }

                                  setState(() {
                                    _previousDateData = data;
                                    _standardHours = result;
                                    _isHoliday = holidayResult;
                                    _taskSummary = TaskSummaryResponse(
                                      ToDoCount: _taskSummary?.ToDoCount ?? 0,
                                      InProgressCount: inProgressCount,
                                      CompleteCount: doneCount,
                                    );
                                    _isLoading = false;
                                  });

                                  _handleRealtimeTimer();

                                  if (data.taskList.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'No records found for selected date',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  print('Error: $e');
                                  setState(() {
                                    _isLoading = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to load data: $e'),
                                    ),
                                  );
                                }
                              },
                              headerProps: const EasyHeaderProps(
                                monthPickerType: MonthPickerType.switcher,
                              ),
                              dayProps: const EasyDayProps(
                                dayStructure: DayStructure.dayStrDayNum,
                                activeDayStyle: DayStyle(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(8.0),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xff3371FF),
                                        Color.fromARGB(255, 0, 6, 114),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_selectedDate.isAfter(DateTime.now())) ...[
                            SizedBox(
                              width: double.infinity,
                              height: SizeConfig.h(10),
                              child: Card(
                                margin: EdgeInsets.only(top: SizeConfig.h(2)),
                                color: Color.fromARGB(255, 255, 233, 200),
                                child: Padding(
                                  padding: EdgeInsetsGeometry.symmetric(horizontal: SizeConfig.w(9)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "No data exists for future dates. Please select a past or current date.",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.orange,
                                        ),
                                      )
                                    ],
                                  ),
                                )
                              ),
                            )
                          ] else ...[
                            // BODY CONTENT
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.fromLTRB(
                                SizeConfig.w(2),
                                SizeConfig.w(3),
                                SizeConfig.w(2),
                                SizeConfig.w(3),
                              ),
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(245, 246, 245, 245),
                                borderRadius: BorderRadius.circular(
                                  SizeConfig.w(3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // SUMMARY SECTION
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Summary of your work',
                                        style: TextStyle(
                                          fontSize: SizeConfig.f(16),
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w600,
                                          color: const Color.fromARGB(
                                            255,
                                            16,
                                            24,
                                            40,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: SizeConfig.h(0.5)),
                                      Text(
                                        'Your current task progress',
                                        style: TextStyle(
                                          fontSize: SizeConfig.f(14),
                                          fontFamily: 'Inter',
                                          fontWeight: FontWeight.w400,
                                          color: const Color.fromARGB(
                                            255,
                                            71,
                                            84,
                                            103,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: SizeConfig.h(2)),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildSummaryCard(
                                            icon: Icons.code_sharp,
                                            iconColor: Colors.white,
                                            backgroundColor: Color.fromARGB(
                                              255,
                                              122,
                                              90,
                                              248,
                                            ),
                                            title: 'To Do',
                                            count:
                                                _taskSummary?.ToDoCount
                                                    .toString() ??
                                                '0',
                                            width: SizeConfig.w(28.5),
                                            height: SizeConfig.h(13),
                                          ),
                                          _buildSummaryCard(
                                            icon: Icons.watch_later_outlined,
                                            iconColor: Colors.white,
                                            backgroundColor: Color.fromARGB(
                                              255,
                                              247,
                                              144,
                                              9,
                                            ),
                                            title: 'In Progress',
                                            count:
                                                _taskSummary?.InProgressCount
                                                    .toString() ??
                                                '0',
                                            width: SizeConfig.w(28.5),
                                            height: SizeConfig.h(13),
                                          ),
                                          _buildSummaryCard(
                                            icon: Icons.done_rounded,
                                            iconColor: Colors.white,
                                            backgroundColor: Color.fromARGB(
                                              255,
                                              25,
                                              179,
                                              110,
                                            ),
                                            title: 'Done',
                                            count:
                                                _taskSummary?.CompleteCount
                                                    .toString() ??
                                                '0',
                                            width: SizeConfig.w(28.5),
                                            height: SizeConfig.h(13),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: SizeConfig.h(2)),

                                // Holiday
                                if (_isHoliday) ...[
                                  Card(
                                    elevation: 4,
                                    color: Colors.grey[500],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: SizeConfig.h(3),
                                        horizontal: SizeConfig.w(4),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.event_busy,
                                            color: Colors.white,
                                            size: SizeConfig.f(22),
                                          ),
                                          SizedBox(width: SizeConfig.w(2)),
                                          Text(
                                            'Today is an Off Day',
                                            style: TextStyle(
                                              fontSize: SizeConfig.f(16),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: SizeConfig.h(2)),
                                ] else ...[
                                  // Standard Hours Section
                                  Card(
                                    color: Colors.white,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: SizeConfig.w(6),
                                        vertical: SizeConfig.h(3.8),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          /// ---- Left Side (Text Data) ----
                                          Expanded(
                                            flex: 1,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  "Standard Hours",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _standardHours
                                                          ?.StandardHours ??
                                                      "0h 0m",
                                                  style: const TextStyle(
                                                    fontSize: 28,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF3B73C6),
                                                  ),
                                                ),
                                                const SizedBox(height: 20),
                                                const Text(
                                                  "Overtime",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  _isTodaySelected() &&
                                                          _isUserCheckedIn()
                                                      ? _realTimeOvertime
                                                      : (_standardHours
                                                                ?.OverTime ??
                                                            "0h 0m"),
                                                  style: const TextStyle(
                                                    fontSize: 26,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF3B73C6),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                            /// ---- Right Side (Circular Indicator) ----
                                            Expanded(
                                              flex: 1,
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  SizedBox(
                                                    height: SizeConfig.h(18),
                                                    width: SizeConfig.w(42),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 18,
                                                      value: 1.0,
                                                      backgroundColor: Colors.grey.shade300,
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.transparent),
                                                    ),
                                                  ),
                                                  
                                                  SizedBox(
                                                    height: SizeConfig.h(18),
                                                    width: SizeConfig.w(42),
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 18,
                                                      value: _isTodaySelected() && _isUserCheckedIn()
                                                          ? _realTimeProgress
                                                          : _calculateInverseProgress(
                                                              _standardHours?.WorkingHours,
                                                              _standardHours?.StandardHours,
                                                              _standardHours?.OverTime,
                                                            ),
                                                      backgroundColor: Colors.transparent,
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        _isTodaySelected() && _isUserCheckedIn()
                                                            ? _progressColor
                                                            : _getProgressColor(
                                                                _standardHours?.WorkingHours,
                                                                _standardHours?.StandardHours,
                                                                _standardHours?.OverTime,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                  
                                                  Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        _isTodaySelected() && _isUserCheckedIn()
                                                            ? _realTimeWorkingHours
                                                            : (_standardHours?.WorkingHours ?? "0h 0m"),
                                                        style: const TextStyle(
                                                          fontSize: 24,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      const Text(
                                                        "Working Hours",
                                                        style: TextStyle(fontSize: 14),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: SizeConfig.h(2)),
                                  ],

                                // ATTENDANCE SECTION

                                if (_isLeave && _isTodaySelected() && _getCheckInTime() == "--:--" && _getCheckOutTime() == "--:--") ...[
                                  Card(
                                    elevation: 4,
                                    color: Color.fromARGB(255, 244, 150, 34),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: SizeConfig.h(3),
                                        horizontal: SizeConfig.w(4),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.event_busy,
                                            color: const Color.fromARGB(
                                              255,
                                              255,
                                              233,
                                              208,
                                            ),
                                            size: SizeConfig.f(22),
                                          ),
                                          SizedBox(width: SizeConfig.w(2)),
                                          Text(
                                            'You are on leave today.',
                                            style: TextStyle(
                                              fontSize: SizeConfig.f(16),
                                              fontWeight: FontWeight.bold,
                                              color: const Color.fromARGB(
                                                255,
                                                255,
                                                233,
                                                208,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: SizeConfig.h(2)),
                                ] else if (_previousDateData != null &&
                                    _previousDateData!.isLeave && _getCheckInTime() == "--:--" && _getCheckOutTime() == "--:--") ...[
                                  Card(
                                    elevation: 4,
                                    color: const Color.fromARGB(
                                      255,
                                      244,
                                      150,
                                      34,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: SizeConfig.h(3),
                                        horizontal: SizeConfig.w(4),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.event_busy_outlined,
                                            color: const Color.fromARGB(
                                              255,
                                              255,
                                              233,
                                              208,
                                            ),
                                            size: SizeConfig.f(22),
                                          ),
                                          SizedBox(width: SizeConfig.w(2)),
                                          Text(
                                            'You were on leave.',
                                            style: TextStyle(
                                              fontSize: SizeConfig.f(16),
                                              fontWeight: FontWeight.bold,
                                              color: const Color.fromARGB(
                                                255,
                                                255,
                                                233,
                                                208,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: SizeConfig.h(2)),
                                ]  else ...[
  Text(
    _isTodaySelected() ? 'Today Attendance' : 'Attendance History',
    style: TextStyle(
      fontSize: SizeConfig.f(16),
      fontFamily: 'Inter',
      fontWeight: FontWeight.w600,
      color: const Color.fromARGB(255, 38, 40, 16),
    ),
  ),
  SizedBox(height: SizeConfig.h(1.5)),

  // If there's data for today or previous day
  if (_todayAttendance != null || _previousDateData?.checkIn != null) ...[
    Row(
      children: [
        // Check-In Card
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            child: _buildAttendanceCard(
              icon: Icons.login,
              title: 'Check In',
              time: _getCheckInTime(),
              titleFontSize: SizeConfig.f(14),
              iconColor: Color.fromARGB(255, 52, 199, 89),
              height: SizeConfig.h(15),
            ),
          ),
        ),
        SizedBox(width: SizeConfig.w(2)),

        // Check-Out Card
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            child: _buildAttendanceCard(
              icon: Icons.logout,
              title: 'Check Out',
              time: _getCheckOutTime(),
              titleFontSize: SizeConfig.f(14),
              iconColor: Color.fromARGB(255, 247, 144, 9),
              height: SizeConfig.h(15),
            ),
          ),
        ),
      ],
    ),
  ] else ...[
    // If no check-in/check-out exists, allow manual addition
    Row(
      children: [
        // Check-In
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.all(SizeConfig.w(4)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(SizeConfig.w(3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: SizeConfig.f(12),
                        backgroundColor: Color.fromARGB(255, 52, 199, 89),
                        child: Icon(
                          Icons.login,
                          color: Colors.white,
                          size: SizeConfig.f(14),
                        ),
                      ),
                      SizedBox(width: SizeConfig.w(2)),
                      Text(
                        'Check In',
                        style: TextStyle(
                          fontSize: SizeConfig.f(14),
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 30, 30, 30),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SizeConfig.h(1)),
                  Text(
                    _getCheckInTime(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: SizeConfig.f(15),
                      color: !_isTodaySelected() ? Colors.blue : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: SizeConfig.w(2)),

        // Check-Out
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.all(SizeConfig.w(4)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(SizeConfig.w(3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: SizeConfig.f(12),
                        backgroundColor: Color.fromARGB(255, 247, 144, 9),
                        child: Icon(
                          Icons.logout,
                          color: Colors.white,
                          size: SizeConfig.f(14),
                        ),
                      ),
                      SizedBox(width: SizeConfig.w(2)),
                      Text(
                        'Check Out',
                        style: TextStyle(
                          fontSize: SizeConfig.f(14),
                          fontWeight: FontWeight.bold,
                          color: const Color.fromARGB(255, 30, 30, 30),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: SizeConfig.h(1)),
                  Text(
                    _getCheckOutTime(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: SizeConfig.f(15),
                      color: !_isTodaySelected() ? Colors.blue : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  ],
  SizedBox(height: SizeConfig.h(1)),
],
                                SizedBox(height: SizeConfig.h(2)),

                                  // Task Section Header
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Pending Tasks",
                                        style: TextStyle(
                                          fontSize: SizeConfig.f(16),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "${_pendingTasks.length} Pending",
                                        style: TextStyle(
                                          fontSize: SizeConfig.f(12),
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: SizeConfig.h(1.5)),

                                  // 🔹 Task List
                                  _pendingTasks.isEmpty
                                      ? _buildEmptyTaskWidget()
                                      : _buildPendingTaskList(),

                                  // PREVIOUS DAY TASK
                                  // if (!_isTodaySelected()) ...[
                                  //   Padding(
                                  //     padding: EdgeInsets.symmetric(
                                  //       horizontal: SizeConfig.w(1),
                                  //       vertical: SizeConfig.h(1),
                                  //     ),
                                  //     child: Column(
                                  //       mainAxisAlignment:
                                  //           MainAxisAlignment.start,
                                  //       crossAxisAlignment:
                                  //           CrossAxisAlignment.start,
                                  //       children: [
                                  //         if (_previousDateData != null) ...[
                                  //           SizedBox(height: SizeConfig.h(2)),
                                  //           Text(
                                  //             'Tasks for ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                                  //             style: TextStyle(
                                  //               fontSize: SizeConfig.f(16),
                                  //               fontWeight: FontWeight.w600,
                                  //             ),
                                  //           ),
                                  //           SizedBox(height: SizeConfig.h(1)),
                                  //           if (_previousDateData!
                                  //               .taskList
                                  //               .isNotEmpty) ...[
                                  //             ..._previousDateData!.taskList
                                  //                 .map(
                                  //                   (item) => Card(
                                  //                     margin:
                                  //                         EdgeInsets.symmetric(
                                  //                           horizontal:
                                  //                               SizeConfig.w(1),
                                  //                           vertical:
                                  //                               SizeConfig.h(0.5),
                                  //                         ),
                                  //                     color: Colors.white,
                                  //                     child: Padding(
                                  //                       padding:
                                  //                           EdgeInsets.symmetric(
                                  //                             horizontal:
                                  //                                 SizeConfig.w(5),
                                  //                             vertical:
                                  //                                 SizeConfig.h(3),
                                  //                           ),
                                  //                       child: Column(
                                  //                         crossAxisAlignment:
                                  //                             CrossAxisAlignment
                                  //                                 .start,
                                  //                         children: [
                                  //                           Text(
                                  //                             item.taskTitle
                                  //                                 .toUpperCase(),
                                  //                             style: TextStyle(
                                  //                               fontWeight:
                                  //                                   FontWeight
                                  //                                       .bold,
                                  //                               fontSize:
                                  //                                   SizeConfig.f(
                                  //                                     14,
                                  //                                   ),
                                  //                             ),
                                  //                           ),
                                  //                           SizedBox(
                                  //                             height:
                                  //                                 SizeConfig.h(
                                  //                                   1.5,
                                  //                                 ),
                                  //                           ),
                                  //                           Row(
                                  //                             mainAxisAlignment:
                                  //                                 MainAxisAlignment
                                  //                                     .spaceBetween,
                                  //                             children: [
                                  //                               Text(
                                  //                                 'Status: ${item.taskStatus.toUpperCase()}',
                                  //                                 style: TextStyle(
                                  //                                   fontSize:
                                  //                                       SizeConfig.f(
                                  //                                         12,
                                  //                                       ),
                                  //                                   color: Colors
                                  //                                       .grey[700],
                                  //                                 ),
                                  //                               ),
                                  //                               Text(
                                  //                                 'Duration: ${_formatTotalHours(item.totalHoursWorked)}',
                                  //                                 style: TextStyle(
                                  //                                   fontSize:
                                  //                                       SizeConfig.f(
                                  //                                         11.5,
                                  //                                       ),
                                  //                                   color: Colors
                                  //                                       .blue,
                                  //                                   fontWeight:
                                  //                                       FontWeight
                                  //                                           .w600,
                                  //                                 ),
                                  //                               ),
                                  //                             ],
                                  //                           ),
                                  //                         ],
                                  //                       ),
                                  //                     ),
                                  //                   ),
                                  //                 )
                                  //                 .toList(),
                                  //           ] else ...[
                                  //             Card(
                                  //               color: Colors.white,
                                  //               child: Padding(
                                  //                 padding: EdgeInsets.symmetric(
                                  //                   horizontal: SizeConfig.w(17),
                                  //                   vertical: SizeConfig.h(3),
                                  //                 ),
                                  //                 child: Text(
                                  //                   'No tasks found for this date',
                                  //                   style: TextStyle(
                                  //                     fontSize: SizeConfig.f(14),
                                  //                     color: const Color.fromARGB(
                                  //                       255,
                                  //                       0,
                                  //                       0,
                                  //                       0,
                                  //                     ),
                                  //                   ),
                                  //                 ),
                                  //               ),
                                  //             ),
                                  //           ],
                                  //         ],
                                  //       ],
                                  //     ),
                                  //   ),
                                  // ],

                                  // ACTIVE TASKS SECTION
                                  if (_activeTasks.isNotEmpty &&
                                      _isTodaySelected()) ...[
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: SizeConfig.w(1),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Active Tasks',
                                            style: TextStyle(
                                              fontSize: SizeConfig.f(16),
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w600,
                                              color: const Color.fromARGB(
                                                255,
                                                16,
                                                24,
                                                40,
                                              ),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      TasksScreen(),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              'View All',
                                              style: TextStyle(
                                                fontSize: SizeConfig.f(14),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ...(_activeTasks
                                        .take(3)
                                        .map((task) => _buildTaskCard(task))),
                                  ] else ...[
                                    SizedBox(height: SizeConfig.h(2)),
                                  ],
                                  //Chart Donut
                                  Text(
                                    'Chart',
                                    style: TextStyle(
                                      fontSize: SizeConfig.f(16),
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w600,
                                      color: const Color.fromARGB(
                                        255,
                                        16,
                                        24,
                                        40,
                                      ),
                                    ),
                                  ),

                                  Card(
                                    color: Colors.white,
                                    elevation: 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      "Start Date",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),

                                                    InkWell(
                                                      onTap: () async {
                                                        DateTime? pickedDate =
                                                            await showDatePicker(
                                                              context: context,
                                                              initialDate:
                                                                  _selectedStartDate,
                                                              firstDate: DateTime(
                                                                2020,
                                                              ),
                                                              lastDate: DateTime(
                                                                2100,
                                                              ),
                                                            );

                                                        if (pickedDate != null) {
                                                          setState(() {
                                                            _selectedStartDate =
                                                                pickedDate;
                                                          });
                                                        }
                                                      },
                                                      child: Container(
                                                        width: SizeConfig.w(40),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 14,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          "${_selectedStartDate.day}-${_selectedStartDate.month}-${_selectedStartDate.year}",
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 28),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      "End Date",
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),

                                                    InkWell(
                                                      onTap: () async {
                                                        DateTime? pickedDate =
                                                            await showDatePicker(
                                                              context: context,
                                                              initialDate:
                                                                  _selectedEndDate,
                                                              firstDate: DateTime(
                                                                2020,
                                                              ),
                                                              lastDate: DateTime(
                                                                2100,
                                                              ),
                                                            );

                                                        if (pickedDate != null) {
                                                          setState(() {
                                                            _selectedEndDate =
                                                                pickedDate;
                                                          });
                                                        }
                                                      },
                                                      child: Container(
                                                        width: SizeConfig.w(40),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 14,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey
                                                                .shade300,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          "${_selectedEndDate.day}-${_selectedEndDate.month}-${_selectedEndDate.year}",
                                                          style: const TextStyle(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 15),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Color.fromARGB(255, 205, 232, 255),
                                                foregroundColor: Colors.blue[700],
                                              ),
                                              onPressed: () async {
                                                final employeeId =
                                                    ApiService.employeeId;
                                                if (employeeId != null) {
                                                  final chart =
                                                      await ApiService.chart(
                                                        employeeId: employeeId,
                                                        endDate: _selectedEndDate,
                                                        dateTime:
                                                            _selectedStartDate,
                                                      );
                                                  setState(() {
                                                    _chart = chart;
                                                  });
                                                }
                                              },
                                              child: Text("Display"),
                                            ),
                                          ),
                                          const SizedBox(height: 15),
                                          Column(
                                            children: [
                                              buildPieChart(),
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  _indicator(
                                                    const Color.fromARGB(
                                                      255,
                                                      138,
                                                      202,
                                                      255,
                                                    ),
                                                    "On Time",
                                                  ),
                                                  const SizedBox(width: 20),
                                                  _indicator(
                                                    const Color.fromARGB(
                                                      255,
                                                      255,
                                                      183,
                                                      178,
                                                    ),
                                                    "Late",
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: SizeConfig.h(4)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ),
                // CHECK IN/OUT SWIPE BUTTON
                if (_isLeave == false &&
                    isApproved == true &&
                    needToRegisterDevice == false &&
                    _isTodaySelected()) ...[
                  if (_todayAttendance?.checkInTime == null) ...[
                    Positioned(
                      left: SizeConfig.w(4),
                      right: SizeConfig.w(4),
                      bottom: SizeConfig.h(0.8),
                      child: SlideAction(
                        borderRadius: SizeConfig.w(9),
                        innerColor: Colors.white,
                        elevation: 4,
                        outerColor: isFaceImageMissing
                            ? Colors.grey
                            : const Color.fromARGB(255, 52, 199, 89),
                        sliderButtonIcon: Icon(
                          Icons.keyboard_arrow_right,
                          color: isFaceImageMissing
                              ? Colors.grey
                              : const Color.fromARGB(255, 52, 199, 89),
                          size: SizeConfig.f(24),
                        ),
                        text: isFaceImageMissing
                            ? '        Upload face image to check in'
                            : 'Swipe to Check In',
                        textStyle: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          fontSize: SizeConfig.f(16),
                        ),
                        onSubmit: () async {
                          if (isFaceImageMissing) {
                            await _captureImage();
                          } else {
                            await _handleAttendance();
                          }
                        },
                      ),
                    ),
                  ] else ...[
                    Positioned(
                      left: SizeConfig.w(2),
                      right: SizeConfig.w(2),
                      bottom: SizeConfig.h(0.8),
                      child: checkProg
                          ? SlideAction(
                              borderRadius: SizeConfig.w(9),
                              innerColor: Colors.white,
                              elevation: 4,
                              outerColor: Colors.grey,
                              sliderButtonIcon: Icon(
                                Icons.keyboard_arrow_right,
                                color: Colors.grey,
                                size: SizeConfig.f(24),
                              ),
                              text: 'Swipe to Check Out',
                              textStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: SizeConfig.f(16),
                              ),
                              onSubmit: _stopTaskFirst,
                            )
                          : SlideAction(
                              borderRadius: SizeConfig.w(9),
                              innerColor: Colors.white,
                              elevation: 4,
                              outerColor: isFaceImageMissing
                                  ? Colors.grey
                                  : Color.fromARGB(255, 247, 144, 9),
                              sliderButtonIcon: Icon(
                                Icons.keyboard_arrow_right,
                                color: isFaceImageMissing
                                    ? Colors.grey
                                    : Color.fromARGB(255, 247, 144, 9),
                                size: SizeConfig.f(24),
                              ),
                              text: isFaceImageMissing
                                  ? '        Upload face image to check out'
                                  : 'Swipe to Check Out',
                              textStyle: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                                fontSize: SizeConfig.f(16),
                              ),
                              onSubmit: () async {
                          if (isFaceImageMissing) {
                            await _captureImage();
                          } else {
                            await _handleAttendance();
                          }
                        },
                            ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
Widget _buildEmptyTaskWidget() {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(SizeConfig.w(5)),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(SizeConfig.w(3)),
    ),
    child: Column(
      children: [
        Icon(
          Icons.task_alt,
          size: SizeConfig.f(28),
          color: Colors.grey,
        ),
        SizedBox(height: SizeConfig.h(1)),
        Text(
          "No pending tasks for today",
          style: TextStyle(
            fontSize: SizeConfig.f(13),
            color: Colors.grey,
          ),
        ),
      ],
    ),
  );
}
Widget _buildPendingTaskList() {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(SizeConfig.w(3)),
      boxShadow: [
        BoxShadow(
          
          color: Colors.grey.withOpacity(0.1),
          blurRadius: 5,
          offset: Offset(0, 3),
        ),
      ],
    ),
        child: Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent, // ✅ REMOVE TOP/BOTTOM LINE
      ),
    child: ExpansionTile(
      initiallyExpanded: false, // show tasks by default
      title: Text(
        "Pending Tasks",
        style: TextStyle(
          fontSize: SizeConfig.f(14),
          fontWeight: FontWeight.bold,
          color: Colors.redAccent, // highlight title
        ),
      ),
      subtitle: Text(
        "${_pendingTasks.length} Pending",
        style: TextStyle(
          fontSize: SizeConfig.f(12),
          color: Colors.redAccent.withOpacity(0.7),
        ),
      ),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: SizeConfig.h(25), // limits height
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: AlwaysScrollableScrollPhysics(),
            itemCount: _pendingTasks.length,
            itemBuilder: (context, index) {
              final task = _pendingTasks[index];
              return _buildTaskItem(task);
            },
          ),
        )
      ],
    ),
        ),
  );
  
}
Widget _buildTaskItem(PendingTask task) {
    if (task.dueTime != null && task.dueTime!.isNotEmpty) {
    dueDateTime = DateTime.tryParse(task.dueTime!);
  }
  return Container(
    margin: EdgeInsets.symmetric(
        horizontal: SizeConfig.w(4), vertical: SizeConfig.h(0.7)),
    padding: EdgeInsets.all(SizeConfig.w(3)),
    decoration: BoxDecoration(
      // color: Colors.redAccent.withOpacity(0.05), // soft highlight
      borderRadius: BorderRadius.circular(SizeConfig.w(2)),
      border: Border.all(
        color: _getPriorityColor(task.priority).withOpacity(0.7),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        // Priority Indicator
        Container(
          width: 5,
          height: SizeConfig.h(5),
          decoration: BoxDecoration(
            color: _getPriorityColor(task.priority),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        SizedBox(width: SizeConfig.w(3)),

        // Task Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: SizeConfig.f(14),
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: SizeConfig.h(0.5)),
              Text(
                task.description ?? "",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SizeConfig.f(12),
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),

        // Due Time
Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    if (dueDateTime != null) ...[
      Text(
        _formatDate(dueDateTime!),
        style: TextStyle(
          fontSize: SizeConfig.f(12),
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      SizedBox(height: 2),
      Text(
        _formatTime(dueDateTime!),
        style: TextStyle(
          fontSize: SizeConfig.f(11),
          color: Colors.grey.shade600,
        ),
      ),
    ] else
      Text(
        "--:--",
        style: TextStyle(
          fontSize: SizeConfig.f(12),
          color: Colors.grey,
        ),
      ),
  ],
),
      ],
    ),
  );
}
Color _getPriorityColor(String priority) {
  switch (priority) {
    case "high":
      return Colors.red;
    case "medium":
      return Colors.orange;
    case "low":
      return Colors.green;
    default:
      return Colors.grey;
  }
}
String _formatDate(DateTime date) {
  return "${date.day.toString().padLeft(2, '0')}-"
         "${date.month.toString().padLeft(2, '0')}-"
         "${date.year}";
}

String _formatTime(DateTime date) {
  return "${date.hour.toString().padLeft(2, '0')}:"
         "${date.minute.toString().padLeft(2, '0')}";
}
  Widget buildPieChart() {
    if (_chart == null) {
      return const Center(child: Text("No Data"));
    }

    final total = _chart!.onTime + _chart!.late;

    if (total == 0) {
      return const Center(child: Text("No Records Found"));
    }

    return SizedBox(
      height: 220,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: [
            PieChartSectionData(
              value: _chart!.onTime.toDouble(),
              title: '${_chart!.onTime}',
              color: const Color.fromARGB(255, 138, 202, 255),
              radius: 60,
            ),
            PieChartSectionData(
              value: _chart!.late.toDouble(),
              title: '${_chart!.late}',
              color: const Color.fromARGB(255, 255, 183, 178),
              radius: 60,
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicator(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text),
      ],
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String count,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(SizeConfig.w(2)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SizeConfig.w(1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              backgroundColor != Colors.white
                  ? CircleAvatar(
                      radius: SizeConfig.f(10),
                      backgroundColor: backgroundColor,
                      child: Icon(
                        icon,
                        color: iconColor,
                        size: SizeConfig.f(11),
                      ),
                    )
                  : Icon(icon, color: iconColor, size: SizeConfig.f(14)),
              SizedBox(width: SizeConfig.w(2)),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: SizeConfig.f(10),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              SizeConfig.w(2),
              SizeConfig.w(0),
              SizeConfig.w(0),
              SizeConfig.w(0),
            ),
            child: Text(
              count,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: SizeConfig.f(26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard({
    required IconData icon,
    required String title,
    required String time,
    required double titleFontSize,
    required Color iconColor,
    required double height,
  }) {
    return Container(
      height: height,
      padding: EdgeInsets.all(SizeConfig.w(4)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SizeConfig.w(3)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: SizeConfig.f(12),
                backgroundColor: iconColor,
                child: Icon(icon, color: Colors.white, size: SizeConfig.f(14)),
              ),
              SizedBox(width: SizeConfig.w(2.5)),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color.fromARGB(255, 30, 30, 30),
                ),
              ),
            ],
          ),
          Text(
            time,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: SizeConfig.f(22),
              color: Color.fromARGB(255, 33, 33, 33),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    if (task.status == "in_progress") {
      checkProg = true;
    } else {
      checkProg = false;
    }

    final isRunning =
        task.timeLogs?.isNotEmpty == true &&
        task.timeLogs?.last.startTime != null &&
        task.timeLogs?.last.stopTime == null;

    Color priorityColor;
    switch (task.priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.orange;
    }

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: SizeConfig.w(1),
        vertical: SizeConfig.h(0.5),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(SizeConfig.w(4)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.taskTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: SizeConfig.f(15),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: SizeConfig.w(2)),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.w(2),
                    vertical: SizeConfig.h(0.5),
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(SizeConfig.w(2)),
                    border: Border.all(color: priorityColor),
                  ),
                  child: Text(
                    task.priority.toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: SizeConfig.f(9),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: SizeConfig.h(1)),
            Text(
              'Assigned by: ${task.assignedByName}',
              style: TextStyle(
                fontSize: SizeConfig.f(11),
                color: Colors.grey[600],
              ),
            ),
            if (task.dueDate != null) ...[
              SizedBox(height: SizeConfig.h(0.5)),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: SizeConfig.f(11),
                    color: Colors.grey,
                  ),
                  SizedBox(width: SizeConfig.w(1)),
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy').format(task.dueDate!.toLocal())}',
                    style: TextStyle(
                      fontSize: SizeConfig.f(11),
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: SizeConfig.h(2)),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: SizeConfig.f(14),
                  color: Colors.blue,
                ),
                SizedBox(width: SizeConfig.w(1)),
                RunningTimer(
                  initialMinutes: task.currentDayStartTime ?? 0,
                  isRunning: isRunning,
                  runningStartTime: isRunning
                      ? task.timeLogs?.last.startTime
                      : null,
                ),
                Spacer(),
                if (isRunning)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: SizeConfig.w(2),
                      vertical: SizeConfig.h(0.5),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(SizeConfig.w(2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: SizeConfig.f(6),
                          height: SizeConfig.f(6),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: SizeConfig.w(1)),
                        Text(
                          'Running',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: SizeConfig.f(10),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: SizeConfig.h(2)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: checkProg
                        ? () => _stopTask(task)
                        : () => _handleStartTask(task),
                    icon: Icon(
                      checkProg ? Icons.stop : Icons.play_arrow,
                      size: SizeConfig.f(16),
                    ),
                    label: Text(
                      checkProg ? 'Stop' : 'Start',
                      style: TextStyle(fontSize: SizeConfig.f(13)),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: checkProg ? Colors.red : Colors.green,
                      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(1)),
                    ),
                  ),
                ),
                SizedBox(width: SizeConfig.w(2)),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _viewTaskDetails(task),
                    icon: Icon(Icons.info_outline, size: SizeConfig.f(16)),
                    label: Text(
                      'Details',
                      style: TextStyle(fontSize: SizeConfig.f(13)),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: SizeConfig.h(1)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleStartTask(TaskModel task) async {
    if (task.taskPreference != 'client') {
      await _startTask(task);
      return;
    }

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showError('Location permission required');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final isAllowed = await ApiService.validateTaskLocation(
        taskId: task.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!isAllowed) {
        _showError('You must be near the client location to start this task');
        return;
      }

      await _startTask(task);
    } catch (e) {
      _showError('Unable to verify location');
    }
  }

  Future<void> _startTask(TaskModel task) async {
    final employeeId = ApiService.employeeId;
    if (employeeId == null) return;

    final result = await ApiService.startTask(
      employeeId: employeeId,
      taskId: task.id,
    );

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task started!'), backgroundColor: Colors.green),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to start task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopTask(TaskModel task) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StopTaskDialog(),
    );

    if (result == null) return;

    final employeeId = ApiService.employeeId;
    if (employeeId == null) return;

    final response = await ApiService.stopTask(
      employeeId: employeeId,
      taskId: task.id,
      notes: result,
    );

    if (response['success'] == true) {
      final todayHours = response['todayHours'];
      checkProg = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task stopped! Today: ${todayHours.toStringAsFixed(1)}h',
          ),
          backgroundColor: Colors.blue,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['error'] ?? 'Failed to stop task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Future<void> _addCheckInTime() async {
  TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (picked == null) return;

  DateTime selectedDateTime = DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    picked.hour,
    picked.minute,
  );

  await markManualCheckIn(selectedDateTime);
}
Future<void> markManualCheckIn(DateTime selectedTime) async {
  if (_previousDateData?.checkIn != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Check-in already exists")),
    );
    return;
  }

  final employeeCode = ApiService.currentEmployee?.employeeId;

  final success = await ApiService.markManualCheckIn(
    employeeCode,
    _selectedDate,
    selectedTime,
  );

  if (success) {
    setState(() {
      _previousDateData =
          _previousDateData?.copyWith(checkIn: selectedTime);
    });
  }
}
Future<void> _addCheckOutTime() async {
  TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.now(),
  );

  if (picked == null) return;

  DateTime selectedDateTime = DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    picked.hour,
    picked.minute,
  );

  await markManualCheckOut(selectedDateTime);
}
Future<void> markManualCheckOut(DateTime selectedTime) async {
  if (_previousDateData?.checkIn == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Check-in required first")),
    );
    return;
  }

  if (selectedTime.isBefore(_previousDateData!.checkIn!)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Checkout must be after check-in")),
    );
    return;
  }

  final employeeCode = ApiService.currentEmployee?.employeeId;

  final success = await ApiService.markManualCheckOut(
    employeeCode,
    _selectedDate,
    selectedTime,
  );

if (success) {
  setState(() {
    if (_previousDateData != null) {
      _previousDateData =
          _previousDateData!.copyWith(checkOut: selectedTime);
    }
  });
}
}
String _getCheckInTime() {
  if (!_isTodaySelected()) {
    if (_previousDateData?.checkIn != null) {
      return DateFormat('hh:mm a').format(_previousDateData!.checkIn!);
    }
    return "--:--";
  }
  return _todayAttendance?.checkInTime != null
      ? DateFormat('hh:mm a').format(_todayAttendance!.checkInTime!.toLocal())
      : '--:--';
}

  void _updateRealTimeData() {
    if (!_isTodaySelected()) return;

    DateTime? checkInTime = _getCheckInDateTime();

    if (checkInTime != null && _todayAttendance?.checkOutTime == null) {
      DateTime now = DateTime.now();
      Duration workingDuration = now.difference(checkInTime);

      int hours = workingDuration.inHours;
      int minutes = workingDuration.inMinutes.remainder(60);
      String newWorkingHours = "${hours}h ${minutes}m";

      double standardHoursValue = _parseHours(
        _standardHours?.StandardHours ?? "8h 30m",
      );
      double workingHoursValue = hours + (minutes / 60);

      String newOvertime;
      if (workingHoursValue > standardHoursValue) {
        double overtimeValue = workingHoursValue - standardHoursValue;
        int overtimeHours = overtimeValue.floor();
        int overtimeMinutes = ((overtimeValue - overtimeHours) * 60).round();
        newOvertime = "${overtimeHours}h ${overtimeMinutes}m";
      } else {
        newOvertime = "0h 0m";
      }

      double newProgress = _calculateInverseProgress(
        newWorkingHours,
        _standardHours?.StandardHours,
        newOvertime,
      );

      Color newColor = _getProgressColor(
        newWorkingHours,
        _standardHours?.StandardHours,
        newOvertime,
      );

      if (_realTimeWorkingHours != newWorkingHours ||
          _realTimeOvertime != newOvertime ||
          _realTimeProgress != newProgress ||
          _progressColor != newColor) {
        setState(() {
          _realTimeWorkingHours = newWorkingHours;
          _realTimeOvertime = newOvertime;
          _realTimeProgress = newProgress;
          _progressColor = newColor;
        });

        print("Real-time update: $_realTimeWorkingHours");
      }
    }
  }

  double _calculateProgress(String? working, String? standard) {
    try {
      int parseMinutes(String? value) {
        if (value == null) return 0;
        final h = RegExp(r'(\d+)h').firstMatch(value);
        final m = RegExp(r'(\d+)m').firstMatch(value);
        final hours = h != null ? int.parse(h.group(1)!) : 0;
        final minutes = m != null ? int.parse(m.group(1)!) : 0;
        return (hours * 60) + minutes;
      }

      final workingMinutes = parseMinutes(working);
      final standardMinutes = parseMinutes(standard);

      if (standardMinutes == 0) return 0;

      double progress = workingMinutes / standardMinutes;
      return progress > 1 ? 1 : progress;
    } catch (e) {
      return 0;
    }
  }

  String _getCheckOutTime() {
    // if (!_isTodaySelected()) {
    //   return _previousDateData != null && _previousDateData?.checkOut != null
    //       ? DateFormat('hh:mm a').format(_previousDateData!.checkOut!)
    //       : '--:--';
    // }
  if (!_isTodaySelected()) {
    if (_previousDateData?.checkOut != null) {
      return DateFormat('hh:mm a').format(_previousDateData!.checkOut!);
    }
    return "--:--";
  }
  return _todayAttendance?.checkOutTime != null
      ? DateFormat('hh:mm a').format(_todayAttendance!.checkOutTime!.toLocal())
      : '--:--';
  }

  void _viewTaskDetails(TaskModel task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => TaskDetailsSheet(task: task, onUpdate: _loadData),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _realtimeTimer?.cancel();
    super.dispose();
  }

  double _calculateInverseProgress(
    String? workingHours,
    String? standardHours,
    String? overtime,
  ) {
    double workingHoursValue = _parseHours(workingHours ?? "0h 0m");
    double standardHoursValue = _parseHours(standardHours ?? "8h 00m");
    double overtimeValue = _parseHours(overtime ?? "0h 0m");

    if (overtimeValue > 0) {
      double maxOvertimeToShow = 2.0;
      double overtimeProgress = (overtimeValue / maxOvertimeToShow).clamp(
        0.0,
        1.0,
      );
      return overtimeProgress;
    }

    if (workingHoursValue >= standardHoursValue) {
      return 0.0;
    }

    double progress = 1.0 - (workingHoursValue / standardHoursValue);
    return progress.clamp(0.0, 1.0);
  }

  Color _getProgressColor(
    String? workingHours,
    String? standardHours,
    String? overtime,
  ) {
    double overtimeValue = _parseHours(overtime ?? "0h 0m");

    if (overtimeValue > 0) {
      return const Color.fromARGB(255, 184, 12, 0);
    }

    return const Color(0xFF3B73C6);
  }

  double _parseHours(String timeString) {
    try {
      List<String> parts = timeString.split(' ');
      double hours = 0;
      double minutes = 0;

      for (String part in parts) {
        if (part.contains('h')) {
          hours = double.parse(part.replaceAll('h', ''));
        } else if (part.contains('m')) {
          minutes = double.parse(part.replaceAll('m', ''));
        }
      }

      return hours + (minutes / 60);
    } catch (e) {
      return 0.0;
    }
  }
}

class RunningTimer extends StatefulWidget {
  final int initialMinutes; // currentDayStartTime
  final DateTime? runningStartTime; // last log start time
  final bool isRunning;

  const RunningTimer({
    super.key,
    required this.initialMinutes,
    required this.isRunning,
    this.runningStartTime,
  });

  @override
  State<RunningTimer> createState() => _RunningTimerState();
}

class _RunningTimerState extends State<RunningTimer> {
  late Duration _duration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _duration = Duration(minutes: widget.initialMinutes);

    if (widget.isRunning && widget.runningStartTime != null) {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final adjustedNow = DateTime.now().toUtc().add(_serverOffset);

      final extra = adjustedNow.difference(widget.runningStartTime!);

      setState(() {
        _duration = Duration(minutes: widget.initialMinutes) + extra;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formatDuration(_duration),
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: Colors.blue,
        fontSize: SizeConfig.f(12),
      ),
    );
  }
}

late Duration _serverOffset;

void calculateOffset(DateTime serverNow) {
  final localNow = DateTime.now().toUtc();
  _serverOffset = serverNow.difference(localNow);
}

String formatDuration(Duration d) {
  final hours = d.inHours.toString().padLeft(2, '0');
  final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String formatHours(int? totalHours) {
  if (totalHours == null) return '0h 0m';
  final duration = Duration(minutes: (totalHours * 60).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return '${hours}h ${minutes}m';
}
