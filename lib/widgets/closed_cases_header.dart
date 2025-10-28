// widgets/closed_cases_header.dart
import 'package:flutter/material.dart';

class ClosedCasesHeader extends StatelessWidget {
  final int casosCerradosCount;
  final VoidCallback onViewClosedCases;

  const ClosedCasesHeader({
    super.key,
    required this.casosCerradosCount,
    required this.onViewClosedCases,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.archive, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                '$casosCerradosCount caso(s) cerrado(s)',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: onViewClosedCases,
            child: const Text(
              'Ver',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}