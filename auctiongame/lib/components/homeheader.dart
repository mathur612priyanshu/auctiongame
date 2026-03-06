// header_widget.dart
import 'package:flutter/material.dart';
import 'package:auctiongame/theme/appcolor.dart';

Widget buildHeader(BuildContext context) {
  return Container(
    padding: EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 5),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    Scaffold.of(context).openDrawer(); // 🟢 Open Drawer
                  },
                ),
                SizedBox(width: 8),
                Image.asset('assets/logo-core.jpg', width: 50, height: 50),
              ],
            ),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.sports_cricket, color: Colors.white, size: 16),
            ),
          ],
        ),
      ],
    ),
  );
}
