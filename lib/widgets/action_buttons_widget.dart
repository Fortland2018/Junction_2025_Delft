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
            label: 'All',
            color: Color(0xFFFC8181), // Czerwony
            icon: Icons.delete_sweep,
            onTap: () => onButtonPressed('ALL'),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Dehumanization',
            color: Color(0xFF667EEA), // Niebieski
            icon: Icons.download,
            onTap: () => onButtonPressed('Dehumanization'),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Violence Advocacy',
            color: Color(0xFF48BB78), // Zielony
            icon: Icons.save,
            onTap: () => onButtonPressed('Violence_advocacy'),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Absolutism',
            color: Color(0xFF9F7AEA), // Fioletowy
            icon: Icons.share,
            onTap: () => onButtonPressed('Absolutism'),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Threat Inflation',
            color: Color(0xFFED8936), // Pomarańczowy
            icon: Icons.settings,
            onTap: () => onButtonPressed('Threat_inflation'),
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Outgroup Homogenization',
            color: Color(0xFF38B2AC), // Turkusowy
            icon: Icons.group,
            onTap: () => onButtonPressed('Outgroup_homogenization'),
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
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
