import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/radio_station.dart';
import 'stations_list_screen.dart';

class RadioPlayerScreen extends StatefulWidget {
  const RadioPlayerScreen({super.key});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> with TickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<RadioStation> _stations = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  Color _dominantColor = const Color(0xFF6C63FF);
  Color _backgroundColor = const Color(0xFF0A0E27);

  late AnimationController _rotationController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _loadStations().then((_) {
      _loadLastStation();
    });
  }

  Future<void> _loadStations() async {
    try {
      final response = await http.get(
        Uri.parse('https://late-tree-7ba3.mandy2a2839.workers.dev/'),
        headers: {
          'User-Agent': 'RadioApp/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        
        List<RadioStation> loadedStations = [];
        
        if (data is List) {
          loadedStations = data
              .where((station) => station['ativo'] == true)
              .map((json) => RadioStation.fromJson(json))
              .where((station) => station.streamUrl.isNotEmpty)
              .toList();
        } else if (data is Map) {
          for (var key in data.keys) {
            if (data[key] is List) {
              loadedStations = (data[key] as List)
                  .where((station) => station['ativo'] == true)
                  .map((json) => RadioStation.fromJson(json))
                  .where((station) => station.streamUrl.isNotEmpty)
                  .toList();
              break;
            }
          }
        }
        
        setState(() {
          _stations = loadedStations;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLastStation() async {
    if (_stations.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt('lastStation') ?? 0;
    if (lastIndex >= 0 && lastIndex < _stations.length) {
      setState(() {
        _currentIndex = lastIndex;
      });
    }
  }

  Future<void> _saveLastStation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastStation', _currentIndex);
  }

  Future<void> _extractDominantColor() async {
    final stationArtwork = _stations[_currentIndex].artUrl;
    if (stationArtwork == null) return;

    try {
      final imageProvider = NetworkImage(stationArtwork);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      setState(() {
        _dominantColor = paletteGenerator.dominantColor?.color ?? const Color(0xFF6C63FF);
        _backgroundColor = Color.lerp(_dominantColor, Colors.black, 0.85)!;
      });
    } catch (e) {
      print('Error extracting color: $e');
    }
  }

  Future<void> _playStation() async {
    if (_stations.isEmpty) return;

    final station = _stations[_currentIndex];
    final stationUrl = station.streamUrl;
    
    if (stationUrl.isEmpty) return;

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(stationUrl);
      await _audioPlayer.play();
      await _saveLastStation();
      await _extractDominantColor();

      setState(() {
        _isPlaying = true;
      });

      _rotationController.repeat();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao reproduzir ${station.name}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      
      setState(() {
        _isPlaying = false;
      });
      _rotationController.stop();
    }
  }

  Future<void> _pauseStation() async {
    await _audioPlayer.pause();
    setState(() {
      _isPlaying = false;
    });
    _rotationController.stop();
  }

  void _nextStation() {
    if (_currentIndex < _stations.length - 1) {
      setState(() {
        _currentIndex++;
      });
      if (_isPlaying) {
        _playStation();
      }
    }
  }

  void _previousStation() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      if (_isPlaying) {
        _playStation();
      }
    }
  }

  void _showStationsList() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StationsListScreen(
          stations: _stations,
          currentIndex: _currentIndex,
          onStationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
            if (_isPlaying) {
              _playStation();
            }
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E27), Colors.black],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: const Color(0xFF6C63FF),
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Carregando estações...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_stations.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E27), Colors.black],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.radio, size: 80, color: Colors.grey),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Nenhuma estação disponível',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Verifique sua conexão com a internet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: _loadStations,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar Novamente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _backgroundColor,
            const Color(0xFF0A0E27),
            Colors.black,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.15),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.radio, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Radio Player',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text(
                        '${_currentIndex + 1}/${_stations.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _isPlaying ? _rotationController.value * 2 * 3.14159 : 0,
                    child: child,
                  );
                },
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _dominantColor.withOpacity(0.6),
                        blurRadius: 60,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(140),
                        child: _stations[_currentIndex].artUrl != null
                            ? Image.network(
                                _stations[_currentIndex].artUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultArtwork();
                                },
                              )
                            : _buildDefaultArtwork(),
                      ),
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.5),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _stations[_currentIndex].name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isPlaying)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.5 + (_pulseController.value * 0.5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _dominantColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.graphic_eq,
                              color: _dominantColor,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tocando agora',
                              style: TextStyle(
                                color: _dominantColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildModernControlButton(
                      icon: Icons.skip_previous_rounded,
                      onPressed: _currentIndex > 0 ? _previousStation : null,
                      size: 60,
                    ),
                    GestureDetector(
                      onTap: _isPlaying ? _pauseStation : _playStation,
                      child: Container(
                        width: 85,
                        height: 85,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _dominantColor,
                              _dominantColor.withOpacity(0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _dominantColor.withOpacity(0.5),
                              blurRadius: 25,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 45,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    _buildModernControlButton(
                      icon: Icons.skip_next_rounded,
                      onPressed: _currentIndex < _stations.length - 1 ? _nextStation : null,
                      size: 60,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ElevatedButton.icon(
                  onPressed: _showStationsList,
                  icon: const Icon(Icons.list_rounded, size: 22),
                  label: const Text(
                    'Ver todas as estações',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.15),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.15),
            Colors.white.withOpacity(0.05),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: size * 0.5),
        onPressed: onPressed,
        color: onPressed != null ? Colors.white : Colors.white.withOpacity(0.3),
      ),
    );
  }

  Widget _buildDefaultArtwork() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _dominantColor,
            _dominantColor.withOpacity(0.6),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.radio,
          size: 120,
          color: Colors.white,
        ),
      ),
    );
  }
}