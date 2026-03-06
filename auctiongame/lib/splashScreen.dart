import 'dart:async';

import 'package:auctiongame/main.dart';
import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:package_info_plus/package_info_plus.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  String _version = "";
  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = "${info.version}+${info.buildNumber}";
    });
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _loadAppVersion();
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(0.2, 0.9, curve: Curves.easeInOut),
      ),
    );

    _animationController.forward();

    Timer(const Duration(seconds: 3), () {
      // Navigate to home screen after 3 seconds
      // Replace this with your actual home screen navigation
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MyHomePage()),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Animated background particles
          Positioned.fill(
            child: Stack(
              children: [
                // Original background image
                Container(
                  // decoration: BoxDecoration(
                  //   image: DecorationImage(
                  //     image: NetworkImage(currentPlayer['image']),
                  //     fit: BoxFit.cover,
                  //     opacity: 0.1,
                  //   ),
                  // ),
                ),
                // Animated green dots
                ...List.generate(25, (index) {
                  return AnimatedPositioned(
                    duration: Duration(seconds: 3 + (index % 4)),
                    curve: Curves.easeInOut,
                    left: (index * 47.0) % MediaQuery.of(context).size.width,
                    top: (index * 73.0) % MediaQuery.of(context).size.height,
                    child: TweenAnimationBuilder<double>(
                      duration: Duration(seconds: 2 + (index % 3)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(
                            sin(value * 2 * pi + index) * 30,
                            cos(value * 3 * pi + index) * 40,
                          ),
                          child: Transform.scale(
                            scale: 0.5 + (sin(value * 4 * pi + index) * 0.3),
                            child: Container(
                              width: 8 + (index % 4) * 3,
                              height: 8 + (index % 4) * 3,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primaryColor.withOpacity(0.8),
                                    AppColors.primaryColor.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.7, 1.0],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryColor.withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart animation
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  );
                }),
                // Additional floating particles
                ...List.generate(15, (index) {
                  return Positioned(
                    left: (index * 83.0) % MediaQuery.of(context).size.width,
                    top: (index * 97.0) % MediaQuery.of(context).size.height,
                    child: TweenAnimationBuilder<double>(
                      duration: Duration(seconds: 4 + (index % 2)),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.linear,
                      builder: (context, value, child) {
                        return Transform.rotate(
                          angle: value * 2 * pi,
                          child: Transform.translate(
                            offset: Offset(
                              cos(value * 3 * pi) * 25,
                              sin(value * 2 * pi) * 35,
                            ),
                            child: Container(
                              width: 4 + (index % 3) * 2,
                              height: 4 + (index % 3) * 2,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF95D5B2).withOpacity(0.6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF95D5B2).withOpacity(0.3),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart animation
                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          // Centered text content
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'WELCOME TO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'CORE',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontSize: 52,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 3,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Play Real. Rise Beyond.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.5,
                              ),
                              textAlign: TextAlign.left,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Rule the Game.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.5,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    Text(
                      "v: $_version",
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    // FadeTransition(
                    //   opacity: _fadeAnimation,
                    //   child: Row(
                    //     mainAxisAlignment: MainAxisAlignment.center,
                    //     children: [
                    //       _buildSportIcon(Icons.sports_cricket_rounded),
                    //       const SizedBox(width: 20),
                    //       _buildSportIcon(Icons.sports_football_rounded),
                    //       const SizedBox(width: 20),
                    //       _buildSportIcon(Icons.sports_soccer_rounded),
                    //     ],
                    //   ),
                    // ),
                    // const SizedBox(height: 50),
                    // FadeTransition(
                    //   opacity: _fadeAnimation,
                    //   child: const SizedBox(
                    //     width: 40,
                    //     height: 40,
                    //     child: CircularProgressIndicator(
                    //       valueColor: AlwaysStoppedAnimation<Color>(
                    //         Colors.white,
                    //       ),
                    //       strokeWidth: 3,
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSportIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, size: 30, color: Colors.white),
    );
  }
}
