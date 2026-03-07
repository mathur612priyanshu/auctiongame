import 'dart:io';
import 'dart:typed_data';

import 'package:auctiongame/api/authservice.dart';
import 'package:auctiongame/main.dart';
import 'package:auctiongame/screens/home/homescreen.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Controller for the animation between steps
  late TabController _tabController;

  // Controllers for form fields
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  bool _isLoading = false;
  // Form keys for validation
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      // Read image as bytes (works on both Web and Mobile)
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = pickedFile.name;
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  // Selected country code
  String _selectedCountryCode = '+91';

  // List of country codes
  final List<String> _countryCodes = ['+1', '+44', '+91', '+61', '+86'];

  // OTP fields
  final List<TextEditingController> _otpFieldControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    6,
    (index) => FocusNode(),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // This will rebuild the UI when tab changes
    });

    // Set up OTP field focus changes
    for (int i = 0; i < 5; i++) {
      _otpFocusNodes[i].addListener(() {
        if (_otpFieldControllers[i].text.length == 1) {
          FocusScope.of(context).requestFocus(_otpFocusNodes[i + 1]);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _dobController.dispose();

    for (var controller in _otpFieldControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  // Method to go to next step
  void _nextStep() {
    if (_tabController.index < 2) {
      _tabController.animateTo(_tabController.index + 1);
    }
  }

  // Method to go to previous step
  void _previousStep() {
    if (_tabController.index > 0) {
      _tabController.animateTo(_tabController.index - 1);
    }
  }

  // Method to validate phone number
  bool _validatePhone() {
    return _phoneFormKey.currentState?.validate() ?? false;
  }

  // Method to validate OTP
  bool _validateOTP() {
    return _otpFormKey.currentState?.validate() ?? false;
  }

  // Method to validate profile
  bool _validateProfile() {
    return _profileFormKey.currentState?.validate() ?? false;
  }

  // Method to submit phone number and request OTP
  void _submitPhoneNumber() async {
    // FIX 1: Prevent multiple taps by checking if already loading
    if (_isLoading || !_validatePhone()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final phoneNumber = _phoneController.text.trim();
      final fullPhoneNumber =
          _selectedCountryCode.replaceAll('+', '') + phoneNumber;

      final success = await AuthService.sendOtp(fullPhoneNumber);

      if (success) {
        _nextStep();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to send verification code. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to verify OTP
  void _verifyOTP() async {
    // FIX 1: Prevent multiple taps by checking if already loading
    if (_isLoading || !_validateOTP()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final otp = _combinedOTP;
      final phoneNumber = _phoneController.text.trim();
      final fullPhoneNumber =
          _selectedCountryCode.replaceAll('+', '') + phoneNumber;

      final success = await AuthService.verifyOtp(otp, fullPhoneNumber);

      if (success) {
        // Check if profile is complete
        final userDetails = await AuthService.getUserDetails();

        if (userDetails != null && userDetails['profilecompleted'] == true) {
          // Navigate to home screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => MyHomePage()),
          );
        } else {
          // Go to profile completion step
          _nextStep();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid verification code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Method to complete profile setup
  void _completeProfile() async {
    // FIX 1: Prevent multiple taps by checking if already loading
    if (_isLoading || !_validateProfile()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final dob = _dobController.text.trim();

      if (_selectedImageBytes == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Please select an image first')));
        return; // stop further code execution
      }
      print("===============================> flow yha tk chl rha h ");
      final result = await AuthService.updateProfile(
        name: name,
        email: email,
        dob: dob,
        imageBytes: _selectedImageBytes,
        fileName: _selectedImageName,
      );

      if (result['success']) {
        final userData = result['user'];

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile Created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MyHomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to complete profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Get combined OTP from all fields
  String get _combinedOTP {
    return _otpFieldControllers.map((controller) => controller.text).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              // AppColors.secondaryaccentColor,
              AppColors.accentColor,
              // AppColors.primaryColor,
              AppColors.secondaryaccentColor,
              AppColors.primaryColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Progress indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < 3; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            color:
                                i <= _tabController.index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildPhoneStep(),
                    _buildOTPStep(),
                    _buildProfileStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Phone number input step
  Widget _buildPhoneStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // Logo or app icon
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.6,
                // height: 100,
                child: Image.asset('assets/logo-core.jpg'),
              ),
            ),

            const SizedBox(height: 40),

            // Title
            const Text(
              'Welcome to CORE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Enter your phone number to continue',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 40),

            // Phone number input
            Form(
              key: _phoneFormKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Country code dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      // vertical: 0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCountryCode,
                        dropdownColor: Colors.indigo.shade900,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                        ),
                        style: const TextStyle(color: Colors.white),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCountryCode = newValue!;
                          });
                        },
                        items:
                            _countryCodes.map<DropdownMenuItem<String>>((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Phone number field
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Phone Number',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          // vertical: 16,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (value.length < 10) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _submitPhoneNumber, // FIX 1: Disable button when loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(
                          color: Colors.indigo,
                        ) // FIX 1: Show loading indicator
                        : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 24),

            // Terms and conditions
            Center(
              child: Text(
                'By continuing, you agree to our Terms of Service and Privacy Policy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // OTP verification step
  Widget _buildOTPStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),

            const SizedBox(height: 40),

            // Title
            const Text(
              'Verification Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'We have sent a verification code to $_selectedCountryCode ${_phoneController.text}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 40),

            // OTP input fields
            Form(
              key: _otpFormKey,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (index) => SizedBox(
                    width: 45,
                    child: RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (RawKeyEvent event) {
                        // Handle backspace key
                        if (event is RawKeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace) {
                          if (_otpFieldControllers[index].text.isEmpty &&
                              index > 0) {
                            // If current field is empty and backspace is pressed, go to previous field
                            FocusScope.of(
                              context,
                            ).requestFocus(_otpFocusNodes[index - 1]);
                            _otpFieldControllers[index - 1].clear();
                          } else {
                            // Clear current field
                            _otpFieldControllers[index].clear();
                          }
                        }
                      },
                      child: TextFormField(
                        controller: _otpFieldControllers[index],
                        focusNode: _otpFocusNodes[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1),
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.length == 1 && index < 5) {
                            // Move to next field when digit is entered
                            FocusScope.of(
                              context,
                            ).requestFocus(_otpFocusNodes[index + 1]);
                          }
                        },
                        onTap: () {
                          // Select all text when tapping to make deletion easier
                          _otpFieldControllers[index].selection = TextSelection(
                            baseOffset: 0,
                            extentOffset:
                                _otpFieldControllers[index].text.length,
                          );
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Verify button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _verifyOTP, // FIX 1: Disable button when loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigo.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(
                          color: Colors.indigo,
                        ) // FIX 1: Show loading indicator
                        : const Text(
                          'Verify',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 24),

            // Resend code
            Center(
              child: TextButton(
                onPressed: () {
                  // Implement resend code functionality
                },
                child: Text(
                  'Resend Code',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Profile setup step
  Widget _buildProfileStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              onPressed: _previousStep,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),

            const SizedBox(height: 30),

            // Title
            const Text(
              'Complete Your Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            // Subtitle
            Text(
              'Tell us a bit about yourself',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 30),

            // Profile picture
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      image:
                          _selectedImage != null
                              ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                              : null,
                    ),
                    child:
                        _selectedImage == null
                            ? const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.white,
                            )
                            : null,
                  ),

                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.indigo.shade900,
                            width: 3,
                          ),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Profile form
            Form(
              key: _profileFormKey,
              child: Column(
                children: [
                  // Full name
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Colors.white70,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.white70,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(
                        r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                      ).hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Date of birth
                  TextFormField(
                    controller: _dobController, // Add this line

                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      labelStyle: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      prefixIcon: const Icon(
                        Icons.calendar_today,
                        color: Colors.white70,
                      ),
                      suffixIcon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white70,
                      ),
                    ),
                    readOnly: true,
                    onTap: () async {
                      // Show date picker
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().subtract(
                          const Duration(days: 365 * 18),
                        ),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: ColorScheme.dark(
                                primary: Colors.white,
                                onPrimary: Colors.indigo.shade900,
                                surface: Colors.indigo.shade900,
                                onSurface: Colors.white,
                              ),
                              dialogBackgroundColor: Colors.indigo.shade900,
                            ),
                            child: child!,
                          );
                        },
                      );
                      // Update field if date was picked
                      if (picked != null) {
                        setState(() {
                          _dobController.text =
                              "${picked.day}/${picked.month}/${picked.year}";

                          // Format date as needed
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Complete button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _completeProfile, // FIX 1: Disable button when loading
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.indigo.shade900,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isLoading
                        ? const CircularProgressIndicator(
                          color: Colors.indigo,
                        ) // FIX 1: Show loading indicator
                        : const Text(
                          'Complete Setup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),

            const SizedBox(height: 24),

            // Skip for now
            // Center(
            //   child: TextButton(
            //     onPressed: () {
            //       // Handle skip functionality
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(
            //           content: Text('You can complete your profile later'),
            //           backgroundColor: Colors.orange,
            //         ),
            //       );
            //     },
            //     child: Text(
            //       'Skip for now',
            //       style: TextStyle(
            //         color: Colors.white.withOpacity(0.8),
            //         fontSize: 16,
            //         fontWeight: FontWeight.bold,
            //       ),
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
