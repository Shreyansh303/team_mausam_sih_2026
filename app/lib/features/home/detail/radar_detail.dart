import 'package:flutter/material.dart';

import '../../../core/formatters.dart';
import '../../../data/models/card.dart';
import '../renderers/parts.dart';
import '../renderers/radar.dart';

/// Full-screen body for the `radar` renderer (docs/02 card 6): the same RainViewer frames on a
/// taller, pannable map with a frame slider — the loop docs/06 asks the map page to own, at the
/// size a card cannot give it.
class RadarDetail extends StatefulWidget {
  const RadarDetail({super.key, required this.card});

  final HomeCard card;

  @override
  State<RadarDetail> createState() => _RadarDetailState();
}

class _RadarDetailState extends State<RadarDetail> {
  int? _index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = RadarSpec.of(widget.card);

    if (spec == null || !spec.hasFrames) {
      return const SizedBox(height: 220, child: RadarUnavailable());
    }

    final last = spec.frames.length - 1;
    final index = (_index ?? last).clamp(0, last);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 320,
            child: RadarMap(spec: spec, frameIndex: index, interactive: true),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Frame ${index + 1} of ${spec.frames.length}',
                style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(Fmt.dateTime(spec.frames[index].time),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ],
        ),
        if (last > 0)
          Slider(
            value: index.toDouble(),
            min: 0,
            max: last.toDouble(),
            divisions: last,
            label: Fmt.time(spec.frames[index].time),
            onChanged: (v) => setState(() => _index = v.round()),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (spec.rainWithin2hPct != null)
              StatCell(
                label: 'Rain within 2 h',
                value: Fmt.pct(spec.rainWithin2hPct),
                icon: Icons.radar,
              ),
            const SizedBox(width: 24),
            StatCell(
              label: 'Frames',
              value: '${spec.frames.length}',
              icon: Icons.movie_filter_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Base map © OpenStreetMap contributors · radar frames from RainViewer. '
          'Times are the frame\'s own timestamp.',
          style:
              theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
