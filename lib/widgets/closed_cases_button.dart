// widgets/closed_cases_button.dart
import 'package:flutter/material.dart';

class ClosedCasesButton extends StatelessWidget {
  final int casosCerradosCount;
  final VoidCallback onPressed;

  const ClosedCasesButton({
    super.key,
    required this.casosCerradosCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: IconButton(
        onPressed: onPressed,
        icon: Stack(
          children: [
            const Icon(Icons.archive, size: 28),
            if (casosCerradosCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    casosCerradosCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        tooltip: 'Ver casos cerrados ($casosCerradosCount)',
      ),
    );
  }
}