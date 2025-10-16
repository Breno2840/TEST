import 'package:flutter/material.dart';
import '../models/radio_station.dart';

class StationsListScreen extends StatelessWidget {
  final List<RadioStation> stations;
  final int currentIndex;
  final Function(int) onStationSelected;

  const StationsListScreen({
    super.key,
    required this.stations,
    required this.currentIndex,
    required this.onStationSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0E27),
            Color(0xFF000000),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Estações de Rádio',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: stations.length,
          itemBuilder: (context, index) {
            final station = stations[index];
            final isPlaying = index == currentIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPlaying
                      ? [
                          const Color(0xFF6C63FF).withOpacity(0.3),
                          const Color(0xFF6C63FF).withOpacity(0.1),
                        ]
                      : [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.03),
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPlaying
                      ? const Color(0xFF6C63FF).withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    onStationSelected(index);
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isPlaying
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF6C63FF).withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: station.artUrl != null
                                ? Image.network(
                                    station.artUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFF6C63FF),
                                              const Color(0xFF6C63FF).withOpacity(0.6),
                                            ],
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.radio,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFF6C63FF),
                                          const Color(0xFF6C63FF).withOpacity(0.6),
                                        ],
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.radio,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                station.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isPlaying ? const Color(0xFF6C63FF) : Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isPlaying) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.graphic_eq,
                                      size: 14,
                                      color: const Color(0xFF6C63FF),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tocando agora',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: const Color(0xFF6C63FF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 18,
                          color: isPlaying
                              ? const Color(0xFF6C63FF)
                              : Colors.white.withOpacity(0.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}