import 'package:auctiongame/theme/appcolor.dart';
import 'package:flutter/material.dart';
import 'dart:math';

class LoaderWidget extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final String imageAssetPath;
  final String text;

  const LoaderWidget({
    Key? key,
    required this.child,
    required this.isLoading,
    required this.imageAssetPath,
    required this.text,
  }) : super(key: key);

  @override
  State<LoaderWidget> createState() => _LoaderWidgetState();
}

class _LoaderWidgetState extends State<LoaderWidget>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _dotsController;
  late Animation<double> _animation;

  final List<String> gameQuotes = [
    "Loading your next adventure...",
    "Gathering your inventory...",
    "Summoning epic quests...",
    "Charging your power crystals...",
    "Awakening ancient spirits...",
    "Forging legendary weapons...",
    "Opening mystical portals...",
    "Casting protective spells...",
    "Unlocking secret treasures...",
  ];

  String currentQuote = "";
  final Random random = Random();

  @override
  void initState() {
    super.initState();

    currentQuote = gameQuotes[random.nextInt(gameQuotes.length)];

    _controller = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _dotsController = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: AppColors.accentColor,
      body: Stack(
        children: [
          // Background dots
          ...List.generate(25, (index) {
            return AnimatedBuilder(
              animation: _dotsController,
              builder: (context, child) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;

                final baseX = (index * 73) % screenWidth.toInt();
                final baseY = (index * 97) % screenHeight.toInt();

                final offsetX =
                    (30 * (_dotsController.value * 2 - 1)) *
                    (index % 2 == 0 ? 1 : -1);
                final offsetY =
                    (20 * (_dotsController.value * 2 - 1)) *
                    (index % 3 == 0 ? 1 : -1);

                return Positioned(
                  left: baseX + offsetX,
                  top: baseY + offsetY,
                  child: Opacity(
                    opacity: 0.3 + (0.4 * _dotsController.value),
                    child: Container(
                      width: 4.0 + (index % 3) * 2.0,
                      height: 4.0 + (index % 3) * 2.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryColor,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryColor.withOpacity(0.6),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _animation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryColor.withOpacity(0.1),
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.4),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Image.asset(
                              widget.imageAssetPath,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.videogame_asset,
                                  size: 50,
                                  color: AppColors.primaryColor,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 30),

                Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 15),

                // Random quote
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    currentQuote,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primaryColor.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                SizedBox(height: 20),

                // Simple loading indicator
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryColor,
                    ),
                    strokeWidth: 3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
