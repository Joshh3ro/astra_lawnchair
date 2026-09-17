import 'package:nocterm/nocterm.dart';
import '../theme.dart';

class ChartSeries {
  final String id;
  final String label;
  final List<num> values;
  final Color color;
  final String currentFormatted;
  final String rateFormatted;
  final bool isVisible;

  const ChartSeries({
    required this.id,
    required this.label,
    required this.values,
    required this.color,
    required this.currentFormatted,
    required this.rateFormatted,
    this.isVisible = true,
  });
}

class AsciiChart extends StatelessComponent {
  final String title;
  final List<ChartSeries> series;
  final int height;

  const AsciiChart({
    super.key,
    required this.title,
    required this.series,
    this.height = 4,
  });

  @override
  Component build(BuildContext context) {
    final activeSeries = series.where((s) => s.isVisible).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Render gauge rows
        final gaugeRows = <Component>[];

        if (activeSeries.isEmpty) {
          gaugeRows.add(
            const Center(
              child: Text(
                'All metrics hidden. Press keys 1-4 to toggle gauges on.',
                style: LawnchairTheme.footerDesc,
                textAlign: TextAlign.center,
              ),
            ),
          );
        } else {
          // Compute available bar width based on parent constraints (default to 46 if unbounded)
          final totalWidth = constraints.maxWidth.isFinite ? constraints.maxWidth.toInt() : 74;
          // label (14) + space (1) + val (14) + space (2) + rate (14) + border/padding (4) = 49
          final barWidth = (totalWidth - 48).clamp(24, 70);

        // Find maximum value across all active series to compute relative bar fill
        num globalMax = 1;
        for (final s in activeSeries) {
          for (final v in s.values) {
            if (v > globalMax) globalMax = v;
          }
        }

        for (int i = 0; i < series.length; i++) {
          final s = series[i];
          if (!s.isVisible) continue;

          // Metric's most recent / highest value
          final currentVal = s.values.isEmpty ? 0 : s.values.last;
          final pct = globalMax > 0 ? (currentVal / globalMax).clamp(0.0, 1.0) : 0.0;

          final filledChars = (pct * barWidth).round().clamp(0, barWidth);
          final emptyChars = barWidth - filledChars;
          final filledBar = '█' * filledChars;
          final emptyBar = '░' * emptyChars;

          final keyIndex = i + 1;
          final labelPadded = '[$keyIndex] ${s.label}'.padRight(14);
          final valPadded = s.currentFormatted.padLeft(13);

          gaugeRows.add(
            Row(
              children: [
                SizedBox(
                  width: 14,
                  child: Text(
                    labelPadded,
                    style: TextStyle(color: s.color, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 1),
                SizedBox(
                  width: 13,
                  child: Text(
                    valPadded,
                    style: LawnchairTheme.statValueHighlight,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  filledBar,
                  style: TextStyle(color: s.color, fontWeight: FontWeight.bold),
                ),
                Text(
                  emptyBar,
                  style: const TextStyle(color: Colors.gray),
                ),
                const SizedBox(width: 2),
                Text(
                  '(${s.rateFormatted})',
                  style: LawnchairTheme.statRate,
                ),
              ],
            ),
          );
        }
      }

      return Container(
          decoration: BoxDecoration(
            border: BoxBorder.all(color: LawnchairTheme.borderNormal),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Title & Interactive Toggle Chips
              Row(
                children: [
                  Text(title, style: LawnchairTheme.statSectionHeader),
                  const Spacer(),
                  for (int i = 0; i < series.length; i++) ...[
                    if (i > 0) const SizedBox(width: 1),
                    Text(
                      series[i].isVisible ? '●[${i + 1}] ${series[i].label}' : '○[${i + 1}] ${series[i].label}',
                      style: TextStyle(
                        color: series[i].isVisible ? series[i].color : Colors.gray,
                        fontWeight: series[i].isVisible ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 1),

              // Horizontal Gauge Rows
              ...gaugeRows,

              const SizedBox(height: 1),
              // Footer: Value and Rate summaries for visible series
              Row(
                children: [
                  if (activeSeries.isEmpty)
                    const Text('No metrics visible', style: LawnchairTheme.footerDesc)
                  else
                    for (int i = 0; i < activeSeries.length; i++) ...[
                      if (i > 0) const SizedBox(width: 2),
                      Text(
                        '${activeSeries[i].label}: ',
                        style: TextStyle(color: activeSeries[i].color, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        activeSeries[i].currentFormatted,
                        style: LawnchairTheme.statValueHighlight,
                      ),
                    ],
                  const Spacer(),
                  const Text('[1-4: Toggle]', style: LawnchairTheme.footerDesc),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

