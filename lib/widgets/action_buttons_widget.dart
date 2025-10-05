import 'package:flutter/material.dart';

class ActionButtonsWidget extends StatelessWidget {
  final Function(String) onButtonPressed;

  const ActionButtonsWidget({Key? key, required this.onButtonPressed})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _buildActionButton(
            label: 'All',
            color: const Color(0xFFFC8181),
            icon: Icons.filter_list,
            onTap: () => onButtonPressed('ALL'),
          ),
          _buildActionButton(
            label: 'Vocabulary Filter',
            color: const Color(0xFFED8936),
            icon: Icons.flag,
            onTap: () => onButtonPressed('Vocabulary Filter'),
          ),
          _buildActionButton(
            label: 'Dehumanization',
            color: const Color(0xFF667EEA),
            icon: Icons.person_off,
            onTap: () => onButtonPressed('Dehumanization'),
          ),
          _buildActionButton(
            label: 'Violence Advocacy',
            color: const Color(0xFF48BB78),
            icon: Icons.gavel,
            onTap: () => onButtonPressed('Violence Advocacy'),
          ),
          _buildActionButton(
            label: 'Absolutism',
            color: const Color(0xFF9F7AEA),
            icon: Icons.stop_circle,
            onTap: () => onButtonPressed('Absolutism'),
          ),
          _buildActionButton(
            label: 'Threat Inflation',
            color: const Color(0xFFECC94B),
            icon: Icons.trending_up,
            onTap: () => onButtonPressed('Threat Inflation'),
          ),
          _buildActionButton(
            label: 'Outgroup Homogenization',
            color: const Color(0xFF38B2AC),
            icon: Icons.group_remove,
            onTap: () => onButtonPressed('Outgroup Homogenization'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        constraints: const BoxConstraints(minWidth: 140),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
