import 'package:flutter/material.dart';
import 'home_folded_layout.dart';
import 'home_unfolded_layout.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Z Fold 6 unfolded screen width is typically > 600dp.
        // This threshold dynamically splits the screen into parallel panel mode.
        final isUnfolded = constraints.maxWidth > 600;
        
        return isUnfolded ? const HomeUnfoldedLayout() : const HomeFoldedLayout();
      },
    );
  }
}
