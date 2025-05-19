import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://quiet-net.xyz/');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1C20), Color(0xFF282C34)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Visit our website',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.only(bottom: 32),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Color(0xFFE6F8FF), // much lighter blue, almost white
                    Color(0xFFB3ECFF), // light blue
                    Color(0xFF61DAFB), // brand blue
                  ],
                  stops: [0.3, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: const Color(0xFF61DAFB), width: 1),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _launchURL,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    child: Text(
                      'quiet-net.xyz',
                      style: TextStyle(
                        color: Color(0xFF1A1C20),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    Color(0xFFE6F8FF), // much lighter blue, almost white
                    Color(0xFFB3ECFF), // light blue
                    Color(0xFF61DAFB), // brand blue
                  ],
                  stops: [0.3, 0.7, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Image.asset(
                'assets/gs-logo.png',
                width: 240,
                height: 120,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) => const Icon(
                      Icons.image_not_supported,
                      color: Colors.white38,
                      size: 60,
                    ),
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Text(
                    'This app was created as part of the',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Footprint 2025',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF61DAFB),
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'graduation project',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
