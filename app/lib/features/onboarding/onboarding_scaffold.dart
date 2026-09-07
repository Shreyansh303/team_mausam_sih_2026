import 'package:flutter/material.dart';

/// Shared chrome for the three onboarding pages: progress dots, title/subtitle, scrollable
/// body and a pinned primary button.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    required this.primaryLabel,
    this.onPrimary,
    this.trailing,
    this.steps = 3,
  });

  final int step;
  final int steps;
  final String title;
  final String subtitle;
  final Widget child;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: step > 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < steps; i++)
              Container(
                width: i == step ? 22 : 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: i <= step
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
          ],
        ),
        actions: trailing == null ? null : <Widget>[trailing!],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Text(title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  child,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
