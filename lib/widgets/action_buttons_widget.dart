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
      child: Row(
        children: [
          _buildActionButton(
            label: 'Export Data',
            color: Color(0xFF667EEA), // Niebieski
            icon: Icons.download,
            onTap: () => onButtonPressed('export'),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: 'Save Project',
            color: Color(0xFF48BB78), // Zielony
            icon: Icons.save,
            onTap: () => onButtonPressed('save'),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: 'Share',
            color: Color(0xFF9F7AEA), // Fioletowy
            icon: Icons.share,
            onTap: () => onButtonPressed('share'),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: 'Settings',
            color: Color(0xFFED8936), // Pomarańczowy
            icon: Icons.settings,
            onTap: () => onButtonPressed('settings'),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: 'Analyze',
            color: Color(0xFF38B2AC), // Turkusowy
            icon: Icons.analytics,
            onTap: () => onButtonPressed('analyze'),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            label: 'Clear All',
            color: Color(0xFFFC8181), // Czerwony
            icon: Icons.delete_sweep,
            onTap: () => onButtonPressed('clear'),
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
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 44, // Płaski przycisk
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
