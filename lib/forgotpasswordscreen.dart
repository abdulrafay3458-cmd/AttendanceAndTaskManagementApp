import 'package:attendance_app/otp_screen.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  _ForgotPasswordScreenState createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = false;

  Future<void> _resetPassword() async {

    if (_usernameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter Username and Email")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(Duration(seconds: 1)); // simulate api
    final res= await ApiService.verifyopt(_usernameController.text.trim(), _emailController.text.trim(),'') ;
    if(res == true)
    {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP successful sent to your Email.")),
          );
           Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OtpScreen(
          email: _emailController.text,
          username: _usernameController.text,
        ),
      ),
    );
    }
    else
    {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OTP Failed please try again")),
          );
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: Text("Forgot Password"),
        backgroundColor: Color.fromARGB(255, 28, 118, 210),
        foregroundColor: Colors.white,
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [

              SizedBox(height: 40),

              /// ICON
              Icon(
                Icons.lock_reset,
                size: 90,
                color: Color.fromARGB(255, 28, 118, 210),
              ),

              SizedBox(height: 20),

              Text(
                "Reset Your Password",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 10),

              Text(
                "Enter your username and email to receive OTP",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),

              SizedBox(height: 40),

              /// USERNAME
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person, color: Color.fromARGB(255, 28, 118, 210)),
                  
                  labelText: "Username",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              SizedBox(height: 20),

              /// EMAIL
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.email, color: Color.fromARGB(255, 28, 118, 210)),
                  labelText: "Email Address",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              SizedBox(height: 35),

              /// BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(

                  onPressed: _isLoading ? null : _resetPassword,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 28, 118, 210),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),

                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Send OTP",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              SizedBox(height: 20),

              /// BACK TO LOGIN
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text("Back to Login"),
              )

            ],
          ),
        ),
      ),
    );
  }
}