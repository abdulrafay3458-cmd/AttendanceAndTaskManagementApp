import 'dart:convert';
import 'dart:typed_data';
import 'package:attendance_app/models/approvepic.dart';
import 'package:attendance_app/rejectprofile.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/models/employeeprofilemodel.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ApproveProfilePic extends StatefulWidget{

  const ApproveProfilePic({super.key});

  @override
  _ApproveProfilePic createState() => _ApproveProfilePic();
}

class _ApproveProfilePic extends State<ApproveProfilePic>{
  List<EmployeeProfileModel> _empProfile = [];
  bool _isLoading = true;
  // Uint8List? _employeeFaceBytes;

   @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    setState(() => _isLoading = true);
    final empId = ApiService.currentEmployee?.employeeId;
    if (empId != null) {
      final data = await ApiService.getEmployeeProfileData(empId);
      setState(() {
          _empProfile = data;
        // _empProfile = data
            // .map((json) => EmployeeProfileModel.fromJson(json))
            // .toList();
        _isLoading = false;
      });
    }
  }

Future<void> _rejectPhoto(
    EmployeeProfileModel profile,
    String reason,
) async {

  final result = await ApiService.approveProfilePic(
    profile.code,
    ApprovePicModel(
      code: profile.code,
      employeeCode: profile.employeeCode,
      adminCode: ApiService.currentEmployee!.employeeId,
      approveDate: null,
      status: false,
      rejectionDate: DateTime.now(),
      rejectionReason: reason,
      historyStatus: true,
      companyCode: profile.companyCode,
    ),
  );

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile photo rejected successfully'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() {
        _empProfile.removeWhere((p) => p.code == profile.code);
      });
      // _loadPendingApprovals();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to reject'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Uint8List? _imageDecoder(String value) {
    try {
      if (value.isEmpty) return null;

      return base64Decode(value);
    } catch (e) {
      debugPrint('Invalid base64 image: $e');
      return null;
    }
  }

  Future<void> _approvePhoto(EmployeeProfileModel profile) async {
  final imageBytes = _imageDecoder(profile.faceImage);

  final confirm = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: Text(
        'Approve Profile Picture', 
        style: TextStyle(fontSize: SizeConfig.f(15), fontWeight: FontWeight.w500),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: SizeConfig.w(50),
            height: SizeConfig.h(30),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes,
                      fit: BoxFit.cover,
                    )
                  : const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Approve profile image for ${profile.employeeName}?',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
TextButton(
  onPressed: () async {
    Navigator.pop(context); // close approve dialog

    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RejectProfileDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      await _rejectPhoto(profile, reason);
    }
  },
  child: const Text(
    'Reject',
    style: TextStyle(color: Colors.red),
  ),
),

        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          child: const Text('Approve'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  final result = await ApiService.approveProfilePic(
    profile.code,
    ApprovePicModel(
      code: profile.code,
      employeeCode: profile.employeeCode,
      adminCode: ApiService.currentEmployee!.employeeId, 
      approveDate: profile.approveDate,
      status: true,
      rejectionDate: null,
      rejectionReason: '',
      historyStatus: true,
      companyCode: profile.companyCode),
  );

  if (result['success'] == true) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile photo approved successfully'),
        backgroundColor: Colors.green,
      ),
    );
    _loadPendingApprovals();
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['error'] ?? 'Failed to approve'),
        backgroundColor: Colors.red,
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Approve Profile Picture',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.f(20),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: 
          // _isLoading 
          // ? Center(child: CircularProgressIndicator())
          // : _empProfile.isEmpty
          // ? Center(
          //     child: Column(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         Icon(
          //           Icons.check_circle_outline,
          //           size: 64,
          //           color: Colors.grey,
          //         ),
          //         SizedBox(height: 16),
          //         Text(
          //           'No pending approvals',
          //           style: TextStyle(fontSize: 16, color: Colors.grey),
          //         ),
          //       ],
          //     ),
          //   )
          // : 
          RefreshIndicator(
              onRefresh: _loadPendingApprovals,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _empProfile.length,
                itemBuilder: (context, index) {
                  final profile = _empProfile[index];
                  return _buildProfileApprove(profile);
                },
              ),
            ),
    );
  }
  
  Widget _buildProfileApprove(EmployeeProfileModel profile){
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 3,
      child: Padding(
        padding: EdgeInsetsGeometry.all(SizeConfig.f(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    // 'KJ',
                    profile.employeeName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        // 'Kamran Jameel',
                        profile.employeeName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        // '00081',
                        profile.employeeCode,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Container(
                //   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                //   decoration: BoxDecoration(
                //     color: Colors.orange.withOpacity(0.1),
                //     borderRadius: BorderRadius.circular(12),
                //     border: Border.all(color: Colors.orange),
                //   ),
                //   child: Text(
                //     // 'Approved',
                //     profile.status ? 'FALSE' : 'TRUE',
                //     // profile.status.toString(),
                //     style: TextStyle(
                //       color: Colors.orange[700],
                //       fontWeight: FontWeight.bold,
                //       fontSize: 11,
                //     ),
                //   ),
                // ),
              ],
            ),
            Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Submitted Date: ${DateFormat('MMM dd, yyyy').format(profile.requestDate)}',
                  style: TextStyle(fontSize: 14),
                ),
                Spacer(),
              ],
            ),
            SizedBox(height: 12),
            // Row(
            //   children: [
            //     Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            //     SizedBox(width: 8),
            //     Text(
            //       'Submitted Date: ${DateFormat('MMM dd, yyyy').format(profile.requestDate)}${profile.rejectionDate != null
            //               ? ' - Rejected Date: ${DateFormat('MMM dd, yyyy').format(profile.rejectionDate!)}'
            //               : (profile.approveDate != null
            //                   ? ' - Approved Date: ${DateFormat('MMM dd, yyyy').format(profile.approveDate!)}'
            //                   : '')}',
            //       style: TextStyle(fontSize: 14),
            //     ),
            //     Spacer(),
            //   ],
            // ),
            // SizedBox(height: 12),
            // Container(
            //   padding: EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: Colors.grey[100],
            //     borderRadius: BorderRadius.circular(8),
            //   ),
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text(
            //         'Reason:',
            //         style: TextStyle(
            //           fontWeight: FontWeight.bold,
            //           fontSize: 12,
            //           color: Colors.grey[700],
            //         ),
            //       ),
            //       SizedBox(width: SizeConfig.w(100)),
            //       Text(profile.rejectionReason ?? '', style: TextStyle(fontSize: 12)),
            //     ],
            //   ),
            // ),
            // SizedBox(height: 12),
            // Text(
            //   'Applied: ${leave.createdAt != null 
            //       ? DateFormat('MMM dd, yyyy hh:mm a').format(leave.createdAt!.toLocal())
            //       : 'N/A'}',
            //   style: TextStyle(fontSize: 11, color: Colors.grey),
            // ),
            // SizedBox(height: 16),
            Row(
              children: [
                // Expanded(
                //   child: OutlinedButton.icon(
                //     onPressed: () => _rejectPhoto(profile),
                //     icon: Icon(Icons.close, size: 18),
                //     label: Text('Reject'),
                //     style: OutlinedButton.styleFrom(
                //       foregroundColor: Colors.red,
                //       side: BorderSide(color: Colors.red),
                //     ),
                //   ),
                // ),
                // SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approvePhoto(profile),
                    icon: Icon(Icons.remove_red_eye_outlined, size: 18),
                    label: Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
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
}