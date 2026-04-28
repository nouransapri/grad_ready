import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../utils/skill_utils.dart';

/// Section showing a list of skill names (matched or missing).
/// [highPrioritySkills] optionally marks which skills to show with a
/// "High priority" badge.
class SkillsListSection extends StatelessWidget {
  final String title;
  final List<String> skills;
  final IconData icon;
  final Color color;
  final Set<String>? highPrioritySkills;
  final Set<String>? mandatorySkills;

  const SkillsListSection({
    super.key,
    required this.title,
    required this.skills,
    required this.icon,
    required this.color,
    this.highPrioritySkills,
    this.mandatorySkills,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uniqueSkills = <String>[];
    final seen = <String>{};
    for (final s in skills) {
      final key = normalizeSkillName(s);
      if (key.isEmpty || !seen.add(key)) continue;
      uniqueSkills.add(s);
    }
    uniqueSkills.sort((a, b) {
      final isMandatoryA = mandatorySkills?.contains(a) ?? false;
      final isMandatoryB = mandatorySkills?.contains(b) ?? false;
      if (isMandatoryA && !isMandatoryB) return -1;
      if (!isMandatoryA && isMandatoryB) return 1;
      return 0; // maintain original order (which is by priority)
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '(${uniqueSkills.length})',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          if (uniqueSkills.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'None',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: uniqueSkills.map((s) {
                final isMandatory = mandatorySkills?.contains(s) ?? false;
                final isHigh = highPrioritySkills?.contains(s) ?? false;
                final short = s.length > 22 ? '${s.substring(0, 22)}…' : s;
                
                Widget? avatar;
                if (isMandatory) {
                  avatar = const Icon(
                    Icons.shield_rounded,
                    size: 14,
                    color: Colors.white,
                  );
                } else if (isHigh) {
                  avatar = const Icon(
                    Icons.priority_high_rounded,
                    size: 14,
                    color: AppTheme.warning,
                  );
                }

                return Chip(
                  label: Text(
                    short,
                    style: TextStyle(
                      fontSize: 12,
                      color: isMandatory ? Colors.white : null,
                      fontWeight: isMandatory ? FontWeight.bold : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  avatar: avatar,
                  backgroundColor: isMandatory
                      ? const Color(0xFFDC2626) // strong red for mandatory
                      : color.withValues(alpha: 0.15),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
