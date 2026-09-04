import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_application_1/config/config.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController repasswordController = TextEditingController();

  // เพิ่ม icon ลูกตาเพื่อเปิดปิด password
  bool _isPasswordVisible = false;
  bool _isRepasswordVisible = false;

  // เพิ่มตัวแปรเช็ค password ไม่ตรงกัน
  bool _isPasswordMismatch = false;

  // เพิ่มตัวแปรเช็คช่องว่าง
  bool _isUsernameEmpty = false;
  bool _isEmailEmpty = false;
  bool _isPasswordEmpty = false;
  bool _isRepasswordEmpty = false;

  // ตัวแปรเช็คข้อมูลซ้ำ
  bool _isUsernameDuplicate = false;
  bool _isEmailDuplicate = false;

  Future<void> registerUser() async {
    final url = Uri.parse(
      'http://$defaultIp:$defaultPort/register',
    ); // เปลี่ยนเลข IP address เป็นของตัวเอง

    // ตรวจสอบช่องว่าง
    setState(() {
      _isUsernameEmpty = usernameController.text.trim().isEmpty;
      _isEmailEmpty = emailController.text.trim().isEmpty;
      _isPasswordEmpty = passwordController.text.trim().isEmpty;
      _isRepasswordEmpty = repasswordController.text.trim().isEmpty;
    });

    // ถ้ามีช่องว่าง
    if (_isUsernameEmpty ||
        _isEmailEmpty ||
        _isPasswordEmpty ||
        _isRepasswordEmpty) {
      await showDialog(
        context: context,
        builder: (context) => _buildPopupDialog(
          context,
          title: "⚠️ Register Failed",
          message: "Please fill in all required fields.",
          isSuccess: false,
        ),
      );
      return;
    }

    // ถ้า password ไม่ตรงกัน ให้แสดงข้อความเตือนและไม่ส่งข้อมูล
    if (passwordController.text.trim() != repasswordController.text.trim()) {
      setState(() {
        _isPasswordMismatch = true;
      });
      await showDialog(
        context: context,
        builder: (context) => _buildPopupDialog(
          context,
          title: "⚠️ Register Failed",
          message: "Passwords do not match.",
          isSuccess: false,
        ),
      );
      return;
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': usernameController.text.trim(),
          'email': emailController.text.trim(),
          'password': passwordController.text.trim(),
          'repassword': repasswordController.text.trim(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // สมัครสำเร็จ
        await showDialog(
          context: context,
          builder: (context) => _buildPopupDialog(
            context,
            title: "🎉 Register Success!",
            message: "Your account has been created successfully.",
            isSuccess: true,
          ),
        );

        usernameController.clear();
        emailController.clear();
        passwordController.clear();
        repasswordController.clear();

        setState(() {
          _isPasswordMismatch = false;
          _isUsernameEmpty = false;
          _isEmailEmpty = false;
          _isPasswordEmpty = false;
          _isRepasswordEmpty = false;
          _isUsernameDuplicate = false;
          _isEmailDuplicate = false;
        });
      } else if (response.statusCode == 409) {
        // ข้อมูลซ้ำ
        setState(() {
          _isUsernameDuplicate = true;
          _isEmailDuplicate = true;
        });
      } else {
        // Error อื่น ๆ
        await showDialog(
          context: context,
          builder: (context) => _buildPopupDialog(
            context,
            title: "⚠️ Register Failed",
            message: response.body.isNotEmpty
                ? response.body
                : "Something went wrong. Please try again.",
            isSuccess: false,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => _buildPopupDialog(
          context,
          title: "❌ Error",
          message: "Could not connect to the server.\n$e",
          isSuccess: false,
        ),
      );
    }
  }

  // Popup Dialog Widget
  Widget _buildPopupDialog(
    BuildContext context, {
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: isSuccess ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSuccess ? Colors.green[800] : Colors.red[800],
            ),
          ),
        ],
      ),
      content: Text(message, style: const TextStyle(fontSize: 16)),
      actions: [
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                "OK",
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[100],
        elevation: 0,
        title: const Text(
          'Register',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 26,
            color: Colors.black,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              Center(
                child: Image.asset('asset/image/registerPic.png', height: 180),
              ),
              const SizedBox(height: 20),

              // Container ฟอร์มสีฟ้าอ่อน
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 25,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildTextField(
                      'Username',
                      'username',
                      usernameController,
                      false,
                      _isUsernameEmpty,
                    ),
                    buildTextField(
                      'E-mail',
                      'e-mail',
                      emailController,
                      false,
                      _isEmailEmpty,
                    ),
                    buildPasswordField(
                      'Password',
                      'password',
                      passwordController,
                      true,
                    ),
                    buildPasswordField(
                      'Re-Password',
                      're-password',
                      repasswordController,
                      false,
                    ),
                    if (_isPasswordMismatch)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 12,
                          top: 4,
                          bottom: 8,
                        ),
                        child: Text(
                          '❌ Passwords do not match',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ปุ่ม Register
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: registerUser,
                      borderRadius: BorderRadius.circular(50),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 12,
                        ),
                        child: Text(
                          'Register',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  // TextField
  Widget buildTextField(
    String label,
    String hint,
    TextEditingController controller,
    bool obscure,
    bool showError,
  ) {
    bool showDuplicateWarning = false;

    if (controller == usernameController) {
      showDuplicateWarning = _isUsernameDuplicate;
    }
    if (controller == emailController) {
      showDuplicateWarning = _isEmailDuplicate;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: (_) {
            setState(() {
              if (controller == usernameController) {
                _isUsernameEmpty = false;
                _isUsernameDuplicate = false;
              }
              if (controller == emailController) {
                _isEmailEmpty = false;
                _isEmailDuplicate = false;
              }
            });
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2.0,
              ),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              '⚠️ This field is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        if (showDuplicateWarning)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              '⚠️ This $label is already taken',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }

  // Password Field with Eye Icon
  Widget buildPasswordField(
    String label,
    String hint,
    TextEditingController controller,
    bool isMainPassword,
  ) {
    bool isVisible = isMainPassword ? _isPasswordVisible : _isRepasswordVisible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[800])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !isVisible,
          onChanged: (value) {
            if (!isMainPassword) {
              setState(() {
                _isPasswordMismatch =
                    passwordController.text.trim() !=
                    repasswordController.text.trim();
                _isRepasswordEmpty = false;
              });
            } else {
              setState(() {
                _isPasswordEmpty = false;
              });
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  if (isMainPassword) {
                    _isPasswordVisible = !_isPasswordVisible;
                  } else {
                    _isRepasswordVisible = !_isRepasswordVisible;
                  }
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30.0),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2.0,
              ),
            ),
          ),
        ),
        if (isMainPassword && _isPasswordEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              '⚠️ This field is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        if (!isMainPassword && _isRepasswordEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: Text(
              '⚠️ This field is required',
              style: TextStyle(color: Colors.red[700], fontSize: 12),
            ),
          ),
        const SizedBox(height: 5),
      ],
    );
  }
}
