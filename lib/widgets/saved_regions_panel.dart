import 'package:flutter/material.dart';
import '../models/saved_regions.dart';

class SavedRegionsPanel extends StatefulWidget {
  final String audioFileName;
  final List<SavedRegion> regions;
  final void Function(SavedRegion) onSelect;
  final void Function(String name) onSave;

  const SavedRegionsPanel({
    super.key,
    required this.audioFileName,
    required this.regions,
    required this.onSelect,
    required this.onSave,
  });

  @override
  State<SavedRegionsPanel> createState() => _SavedRegionsPanelState();
}

class _SavedRegionsPanelState extends State<SavedRegionsPanel> {
  String _typedName = '';

  Future<void> _handleSave() async {
    final name = _typedName.trim();
    if (name.isNotEmpty) {
      widget.onSave(name);
      setState(() {
        _typedName = '';
      });
      await SavedRegion.saveRegions(widget.audioFileName, widget.regions);
    }
  }

  Future<void> _handleDelete(SavedRegion region) async {
    setState(() {
      widget.regions.remove(region);
    });
    await SavedRegion.saveRegions(widget.audioFileName, widget.regions);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            SizedBox(
              width: 300, // Increased width for better usability
              child: TextField(
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFFE5E5E5)),
                decoration: const InputDecoration(
                  labelText: 'Name this region...',
                  labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w400, color: Color(0xFFB8B8B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Color(0xFF5A5A5A), width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Color(0xFF5A5A5A), width: 0.5),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    borderSide: BorderSide(color: Color(0xFFF9931A), width: 1),
                  ),
                  filled: true,
                  fillColor: Color(0xFF1A1A1A),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                ),
                onChanged: (value) {
                  setState(() {
                    _typedName = value;
                  });
                },
                onSubmitted: (_) => _handleSave(),
              ),
            ),
            const SizedBox(width: 8), // Fixed spacing between text field and Save button
            ElevatedButton.icon(
              icon: const Icon(Icons.note_add_outlined, size: 16, color: Color(0xFFE5E5E5)),
              label: const Text(
                "Save",
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFFE5E5E5)),
              ),
              onPressed: _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF393939),
                foregroundColor: const Color(0xFFE5E5E5),
                elevation: 0,
                side: const BorderSide(color: Color(0xFF4A4A4A), width: 0.5),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            const Spacer(), // Expanding spacer to push everything to the right
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Saved Selections:',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 11,
            color: Color(0xFFF9931A),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: widget.regions.isEmpty
              ? const Text('No saved regions yet.', style: TextStyle(color: Color(0xFFB8B8B8), fontSize: 10))
              : ListView.builder(
                  itemCount: widget.regions.length,
                  itemBuilder: (context, index) {
                    final region = widget.regions[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF4A4A4A), width: 0.5),
                      ),
                      child: ListTile(
                        title: Text(
                          region.name,
                          style: const TextStyle(color: Color(0xFFE5E5E5), fontSize: 11, fontWeight: FontWeight.w400),
                        ),
                        leading: const Icon(Icons.music_note, color: Color(0xFFF9931A), size: 16),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFFF6B6B), size: 16),
                          onPressed: () => _handleDelete(region),
                        ),
                        onTap: () => widget.onSelect(region),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
