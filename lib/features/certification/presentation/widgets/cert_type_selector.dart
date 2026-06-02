import 'package:flutter/material.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_template_name.dart';

class CertTypeSelector extends StatelessWidget {
  const CertTypeSelector({super.key, required this.onSelected});
  final ValueChanged<CertType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Select Certificate Type', style: Theme.of(context).textTheme.titleLarge),
        ),
        _TypeTile(
          icon: Icons.science_outlined,
          label: 'OVP Certificate',
          subtitle: 'Performance verification / OVP',
          type: CertType.test,
          onSelected: onSelected,
        ),
        _TypeTile(
          icon: Icons.verified_outlined,
          label: 'QA Certificate',
          subtitle: 'Quality assurance verification',
          type: CertType.qa,
          onSelected: onSelected,
        ),
        _TypeTile(
          icon: Icons.rocket_launch_outlined,
          label: 'Commission Certificate',
          subtitle: 'Commissioning & handover',
          type: CertType.commission,
          onSelected: onSelected,
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.type,
    required this.onSelected,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final CertType type;
  final ValueChanged<CertType> onSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: Icon(icon, color: brandTeal, size: 32),
        title: Text(label, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => onSelected(type),
      ),
    );
  }
}
