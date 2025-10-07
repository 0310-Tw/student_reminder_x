import 'package:flutter/material.dart';

class GroupFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const GroupFilter({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.all(12),
      child: Wrap(
        spacing: 6,
        children: [
          ChoiceChip(
            backgroundColor: Colors.indigoAccent,
            label: Text('Mobile'),
            selected: value == 'mobile',
            onSelected: (_) => onChanged('mobile'),
          ),
          ChoiceChip(
            backgroundColor: Colors.tealAccent,
            label: Text('Web'),
            selected: value == 'web',
            onSelected: (_) => onChanged('web'),
          ),
        ],
      ),
    );
  }
}