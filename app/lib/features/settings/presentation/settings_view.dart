import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/settings_repository.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsRepositoryProvider);
    final notifier = ref.read(settingsRepositoryProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF05050A),
      appBar: AppBar(
        title: const Text("SETTINGS", style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        children: [
          _buildSection("VOICE SETTINGS"),
          
          _buildSliderHeader("Speech Rate", settings.speechRate),
          _buildSlider(settings.speechRate, 0.1, 1.0, (v) => notifier.updateSpeechRate(v)),
          _buildPresets(
            ["Slow", "Normal", "Fast"], 
            [0.3, 0.5, 0.8], 
            settings.speechRate, 
            (v) => notifier.updateSpeechRate(v)
          ),
          
          const SizedBox(height: 32),
          
          _buildSliderHeader("Pitch", settings.pitch),
          _buildSlider(settings.pitch, 0.5, 2.0, (v) => notifier.updatePitch(v)),
          _buildPresets(
            ["Low", "Natural", "High"], 
            [0.5, 1.0, 1.5], 
            settings.pitch, 
            (v) => notifier.updatePitch(v)
          ),
          
          const SizedBox(height: 40),
          _buildSection("EMERGENCY CONTACTS"),
          _buildContactTile("Primary Contact", settings.primaryContactName, settings.primaryContactNumber),
          const Divider(color: Colors.white10, height: 1),
          _buildContactTile("Secondary Contact", settings.secondaryContactName, settings.secondaryContactNumber),
          
          const SizedBox(height: 40),
          Center(
            child: Text(
              "VISION MATE v1.0.2", 
              style: TextStyle(color: Colors.white.withOpacity(0.1), fontSize: 10, letterSpacing: 2)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.cyanAccent, letterSpacing: 3, fontWeight: FontWeight.w900, fontSize: 11)),
          const SizedBox(height: 4),
          Container(width: 40, height: 2, color: Colors.cyanAccent.withOpacity(0.3)),
        ],
      ),
    );
  }

  Widget _buildSliderHeader(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
        Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSlider(double value, double min, double max, Function(double) onChanged) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
        activeTrackColor: Colors.cyanAccent,
        inactiveTrackColor: Colors.white10,
        thumbColor: Colors.cyanAccent,
        overlayColor: Colors.cyanAccent.withOpacity(0.1),
      ),
      child: Slider(
        value: value.clamp(min, max), 
        min: min, 
        max: max, 
        onChanged: onChanged
      ),
    );
  }

  Widget _buildPresets(List<String> labels, List<double> values, double currentValue, Function(double) onSelect) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(labels.length, (index) {
        bool isSelected = (currentValue - values[index]).abs() < 0.05;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: index == labels.length - 1 ? 0 : 4,
            ),
            child: OutlinedButton(
              onPressed: () => onSelect(values[index]),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isSelected ? Colors.cyanAccent : Colors.white10),
                backgroundColor: isSelected ? Colors.cyanAccent.withOpacity(0.05) : Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                labels[index].toUpperCase(), 
                style: TextStyle(
                  color: isSelected ? Colors.cyanAccent : Colors.white24, 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1
                )
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildContactTile(String type, String name, String number) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), shape: BoxShape.circle),
            child: const Icon(Icons.person_outline_rounded, color: Colors.white38, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type, style: const TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  name.isEmpty ? "NOT CONFIGURED" : name, 
                  style: TextStyle(
                    color: name.isEmpty ? Colors.white10 : Colors.white, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  )
                ),
                if (number.isNotEmpty)
                  Text(number, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white10, size: 14),
        ],
      ),
    );
  }
}
