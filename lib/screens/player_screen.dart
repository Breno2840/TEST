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
  bool _isPlaying = false; // Estado visual controlado manualmente
  bool _isLoading = true;
  bool _isBuffering = false;
  Color _dominantColor = const Color(0xFF6C63FF);
  Color _backgroundColor = const Color(0xFF0A0E27);

  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _buttonScaleController;

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

    _buttonScaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
    )..value = 1.0;

    _loadStations().then((_) {
      _loadLastStation();
    });

    // ✅ OUVIMOS O STREAM APENAS PARA DETECTAR ERROS E BUFFERING
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      final processingState = state.processingState;

      setState(() {
        _isBuffering = processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering;
      });

      // ✅ CONTROLE DA ANIMAÇÃO DO CD BASEADO NO ESTADO REAL DO PLAYER
      if (state.playing && processingState == ProcessingState.ready) {
        if (!_rotationController.isAnimating) {
          _rotationController.repeat();
        }
      } else {
        if (_rotationController.isAnimating) {
          _rotationController.stop();
        }
      }
    });

    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        if (mounted) {
          setState(() {
            _isBuffering = false;
            _isPlaying = false; // Forçar estado visual para parado
          });
          _rotationController.stop();
        }
      },
    );
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

        if (mounted) {
          setState(() {
            _stations = loadedStations;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadLastStation() async {
    if (_stations.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastIndex = prefs.getInt('lastStation') ?? 0;

      if (lastIndex >= 0 && lastIndex < _stations.length) {
        if (mounted) {
          setState(() {
            _currentIndex = lastIndex;
          });
        }
        await _extractDominantColor();
      }
    } catch (e) {
      print('Erro ao carregar última estação: $e');
    }
  }

  Future<void> _saveLastStation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('lastStation', _currentIndex);
    } catch (e) {
      print('Erro ao salvar estação: $e');
    }
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

      if (mounted) {
        setState(() {
          _dominantColor = paletteGenerator.dominantColor?.color ?? const Color(0xFF6C63FF);
          _backgroundColor = Color.lerp(_dominantColor, Colors.black, 0.85)!;
        });
      }
    } catch (e) {
      print('Error extracting color: $e');
    }
  }

  Future<void> _playStation() async {
    if (_stations.isEmpty || _isBuffering) return;

    final station = _stations[_currentIndex];
    final stationUrl = station.streamUrl;

    if (stationUrl.isEmpty) return;

    setState(() {
      _isBuffering = true;
      _isPlaying = false;
    });

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(stationUrl);
      await _audioPlayer.play();

      await _saveLastStation();
      await _extractDominantColor();

      if (mounted) {
        setState(() {
          _isPlaying = true; // ✅ ATUALIZAR ESTADO VISUAL
          _isBuffering = false;
        });
      }

      // A animação do CD é controlada pelo stream, não aqui
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível conectar à ${station.name}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );

        setState(() {
          _isPlaying = false;
          _isBuffering = false;
        });
      }
      _rotationController.stop();
    }
  }

  Future<void> _stopStation() async {
    if (_isBuffering) return;

    // Parar a animação imediatamente
    _rotationController.stop();

    try {
      await _audioPlayer.stop();
    } catch (e) {
      print('Erro ao parar: $e');
    }

    // Atualizar o estado visual imediatamente
    if (mounted) {
      setState(() {
        _isPlaying = false; // ✅ FORÇAR ESTADO VISUAL PARA PARADO
        _isBuffering = false;
      });
    }
  }


  Future<void> _togglePlayPause() async {
    if (_isBuffering) return;

    if (_isPlaying) {
      await _stopStation();
    } else {
      await _playStation();
    }
  }

  void _nextStation() {
    if (_currentIndex < _stations.length - 1 && !_isBuffering) {
      setState(() {
        _currentIndex++;
      });
      if (_isPlaying) {
        _playStation();
      } else {
        _extractDominantColor();
        _saveLastStation();
      }
    }
  }

  void _previousStation() {
    if (_currentIndex > 0 && !_isBuffering) {
      setState(() {
        _currentIndex--;
      });
      if (_isPlaying) {
        _playStation();
      } else {
        _extractDominantColor();
        _saveLastStation();
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
            } else {
              _extractDominantColor();
              _saveLastStation();
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
    _buttonScaleController.dispose();
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
          colors: [_backgroundColor, const Color(0xFF0A0E27), Colors.black],
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
                        color: _dominantColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: _dominantColor.withOpacity(0.3), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.radio, size: 20, color: _dominantColor),
                          const SizedBox(width: 8),
                          const Text('Radio Player', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: _dominantColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: _dominantColor.withOpacity(0.3), width: 1.5),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Text('${_currentIndex + 1}/${_stations.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _dominantColor)),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(angle: _isPlaying ? _rotationController.value * 2 * 3.14159 : 0, child: child);
                },
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: _dominantColor.withOpacity(0.6), blurRadius: 60, spreadRadius: 15)],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(140),
                        child: _stations[_currentIndex].artUrl != null
                            ? Image.network(_stations[_currentIndex].artUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildDefaultArtwork())
                            : _buildDefaultArtwork(),
                      ),
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
                          child: Center(child: Container(width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
                        ),
                      ),
                      if (_isBuffering)
                        Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.6)),
                          child: Center(child: CircularProgressIndicator(color: _dominantColor, strokeWidth: 3)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    Text(_stations[_currentIndex].name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
                    if (_stations[_currentIndex].location != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on_rounded, size: 18, color: _dominantColor.withOpacity(0.8)),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(_stations[_currentIndex].location!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_isPlaying && !_isBuffering)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: 0.5 + (_pulseController.value * 0.5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(color: _dominantColor.withOpacity(0.25), borderRadius: BorderRadius.circular(25), border: Border.all(color: _dominantColor.withOpacity(0.4), width: 1.5)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.graphic_eq_rounded, color: _dominantColor, size: 18),
                            const SizedBox(width: 10),
                            Text('Tocando agora', style: TextStyle(color: _dominantColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMaterialYouButton(icon: Icons.skip_previous_rounded, onPressed: _currentIndex > 0 && !_isBuffering ? _previousStation : null, size: 68),
                    _buildMainPlayButton(),
                    _buildMaterialYouButton(icon: Icons.skip_next_rounded, onPressed: _currentIndex < _stations.length - 1 && !_isBuffering ? _nextStation : null, size: 68),
                  ],
                ),
              ),
              const SizedBox(height: 35),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showStationsList,
                    borderRadius: BorderRadius.circular(32),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                      decoration: BoxDecoration(color: _dominantColor.withOpacity(0.2), borderRadius: BorderRadius.circular(32), border: Border.all(color: _dominantColor.withOpacity(0.4), width: 2)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.queue_music_rounded, size: 24, color: _dominantColor),
                          const SizedBox(width: 12),
                          Text('Ver todas as estações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _dominantColor, letterSpacing: 0.3)),
                        ],
                      ),
                    ),
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

  Widget _buildMaterialYouButton({required IconData icon, required VoidCallback? onPressed, required double size}) {
    final isEnabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isEnabled ? _dominantColor.withOpacity(0.25) : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(color: isEnabled ? _dominantColor.withOpacity(0.5) : Colors.white.withOpacity(0.1), width: 2.5),
            boxShadow: isEnabled ? [BoxShadow(color: _dominantColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 1)] : [],
          ),
          child: Icon(icon, size: size * 0.45, color: isEnabled ? _dominantColor : Colors.white.withOpacity(0.3)),
        ),
      ),
    );
  }

  Widget _buildMainPlayButton() {
    return GestureDetector(
      onTapDown: (_) {
        if (!_isBuffering) _buttonScaleController.reverse();
      },
      onTapUp: (_) {
        if (!_isBuffering) _buttonScaleController.forward();
      },
      onTapCancel: () => _buttonScaleController.forward(),
      onTap: _isBuffering ? null : _togglePlayPause,
      child: ScaleTransition(
        scale: _buttonScaleController,
        child: Container(
          width: 95,
          height: 95,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_dominantColor, _dominantColor.withOpacity(0.8)]),
            shape: BoxShape.circle,
            border: Border.all(color: _dominantColor.withOpacity(0.5), width: 3),
            boxShadow: [
              BoxShadow(color: _dominantColor.withOpacity(0.6), blurRadius: 30, spreadRadius: 5),
              BoxShadow(color: _dominantColor.withOpacity(0.3), blurRadius: 60, spreadRadius: 10),
            ],
          ),
          child: _isBuffering
              ? Padding(padding: const EdgeInsets.all(25), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.5))
              : Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 50, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDefaultArtwork() {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [_dominantColor, _dominantColor.withOpacity(0.6)])),
      child: const Center(child: Icon(Icons.radio, size: 120, color: Colors.white)),
    );
  }
}