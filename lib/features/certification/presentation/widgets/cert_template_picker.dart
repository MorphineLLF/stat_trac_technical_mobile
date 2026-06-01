import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_theme.dart';
import '../../domain/entities/test_template_name.dart';
import '../providers/certificate_providers.dart';

class CertTemplatePicker extends ConsumerWidget {
  const CertTemplatePicker({
    super.key,
    required this.certType,
    required this.onSelected,
  });
  final CertType certType;
  final ValueChanged<TestTemplateName> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(templatesByTypeProvider(certType));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Select Template',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Expanded(
          child: templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (templates) => templates.isEmpty
                ? const _EmptyTemplates()
                : ListView.builder(
                    itemCount: templates.length,
                    itemBuilder: (_, i) => _TemplateTile(
                      template: templates[i],
                      onTap: () => onSelected(templates[i]),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onTap});
  final TestTemplateName template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.description_outlined, color: brandTeal),
        title: Text(template.displayName,
            style: Theme.of(context).textTheme.titleMedium),
        subtitle: template.docNo != null ? Text('Doc: ${template.docNo}') : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyTemplates extends StatelessWidget {
  const _EmptyTemplates();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_download_outlined, size: 64, color: brandGrey),
          const SizedBox(height: 16),
          Text(
            'No templates loaded',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Sync to download certificate templates',
            style: TextStyle(color: brandGrey),
          ),
        ],
      ),
    );
  }
}
