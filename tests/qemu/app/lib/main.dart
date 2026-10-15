// ignore: deprecated_member_use
import 'package:flutter/material.dart';

void main() {
  runApp(const ProbeApp());
}

class ProbeApp extends StatelessWidget {
  const ProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Every default text style uses the bundled font, so nothing falls back to
      // the host's fonts.
      theme: ThemeData(fontFamily: 'TitanProbe'),
      // The DEBUG ribbon draws its label with its own text style, not the theme's.
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Container(
            width: 240,
            height: 160,
            color: Colors.blue,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(height: 8),
                Text('Titan probe', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
