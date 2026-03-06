import 'package:flutter/material.dart';

class DateGroupHeader extends StatelessWidget {
  final String fecha;

  const DateGroupHeader({super.key, required this.fecha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.event_note, size: 18, color: Colors.orange.shade300),
          const SizedBox(width: 8),
          Text(
            fecha,
            style: TextStyle(
              color: Colors.grey.shade300,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: Colors.white.withOpacity(0.1),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}