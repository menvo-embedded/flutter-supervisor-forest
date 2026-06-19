import 'package:flutter/material.dart';
import '../widgets/gis_heatmap_widget.dart';

class GisMapPage extends StatelessWidget {
  const GisMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GISHeatmapWidget(),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
