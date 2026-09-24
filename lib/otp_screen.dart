import 'dart:async';
import 'package:attendance_app/login.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String username;

  const OtpScreen({super.key, required this.email,required this.username});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}
class _OtpScreenState extends State<OtpScreen> {

  int _secondsRemaining = 600; // 10 minutes
  Timer? _timer;
List<FocusNode> focusNodes =
    List.generate(6, (index) => FocusNode());
  final List<TextEditingController> otpControllers =
      List.generate(6, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get timerText {
    int minutes = _secondsRemaining ~/ 60;
    int seconds = _secondsRemaining % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text("Enter OTP"),
      backgroundColor: Color.fromARGB(255, 28, 118, 210),
      foregroundColor: Colors.white,
    ),
    body: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [

          Text(
            "OTP sent to ${widget.email}",
            style: TextStyle(fontSize: 16),
          ),

          SizedBox(height: 20),

          Text(
            "Time Remaining: $timerText",
            style: TextStyle(
              color: Colors.red,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 30),

Row(
  mainAxisAlignment: MainAxisAlignment.spaceAround,
  children: List.generate(6, (index) {
    return SizedBox(
      width: 45,
      child: TextField(
        controller: otpControllers[index],
        focusNode: focusNodes[index],
        keyboardType: TextInputType.number,
        maxLength: 1,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          counterText: "",
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          if (value.length == 1 && index < 5) {
            FocusScope.of(context).requestFocus(focusNodes[index + 1]);
          }

          if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(focusNodes[index - 1]);
          }
        },
      ),
    );
  }),
),

         SizedBox(width: 30, height: 30),

ElevatedButton(
  onPressed: () async {

    String otp = otpControllers
        .map((e) => e.text)
        .join();

    print("OTP entered: $otp");

    final res = await ApiService.resetpassword(
        widget.username,
        widget.email,
        otp);
        if (res == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Password successful sent to your Email.")),
        );
         Navigator.push(
         context,
         MaterialPageRoute(
           builder: (context) => LoginScreen(),
         ),
       );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP is incorrect")),
        );
      }
  
     
    
  },
  style: ElevatedButton.styleFrom(
    backgroundColor: Color.fromARGB(255, 28, 118, 210),
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, 50),
  ),
  child: Text("Verify OTP", style: TextStyle(fontWeight: FontWeight.w600),),
)

        ],
      ),
    ),
  );
}
}