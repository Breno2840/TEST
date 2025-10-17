import 'package.flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import '../models/radio_station.dart';
import '../services/radio_api_service.dart';
import '../services/storage_service.dart';

class RadioPlayerController extends ChangeNotifier {
  // Serviços
  final RadioApiService _apiService = RadioApiService();
  final StorageService _storageService = StorageService();

  // Player e Animações
  final AudioPlayer audioPlayer = AudioPlayer();
  late AnimationController rotationController;
  late AnimationController pulseController;
  late AnimationController buttonScaleController;
  
  // Estado da UI
  List<RadioStation> stations = [];
  int currentIndex = 0;
  bool isPlaying = false;
  bool isLoading = true;
  bool isBuffering = false;
  Color dominantColor = const Color(0xFF6C63FF);
  Color backgroundColor = const Color(0xFF0A0E27);

  RadioStation? get currentStation => stations.isNotEmpty ? stations[currentIndex] : null;

  RadioPlayerController({required TickerProvider vsync}) {
    rotationController = AnimationController(duration: const Duration(seconds: 10), vsync: vsync);
    pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: vsync)..repeat(reverse: true);
    buttonScaleController = AnimationController(
        duration: const Duration(milliseconds: 100), vsync: vsync, lowerBound: 0.95, upperBound: 1.0)..value = 1.0;
    
    _init();
  }

  Future<void> _init() async {
    try {
      stations = await _apiService.fetchStations();
      final lastIndex = await _storageService.loadLastStationIndex();
      if (lastIndex >= 0 && lastIndex < stations.length) {
        currentIndex = lastIndex;
      }
      await extractDominantColor();
    } catch (e) {
      print("Erro ao inicializar: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }

    audioPlayer.playerStateStream.listen((state) {
      final buffering = state.processingState == ProcessingState.loading || state.processingState == ProcessingState.buffering;
      if (isBuffering != buffering) {
        isBuffering = buffering;
        notifyListeners();
      }
    });
  }

  Future<void> togglePlayPause() async {
    if (isBuffering) return;

    isPlaying = !isPlaying;

    if (isPlaying) {
      rotationController.repeat();
    } else {
      rotationController.stop();
    }
    
    notifyListeners();

    try {
      if (isPlaying) {
        await _playStation();
      } else {
        await _stopStation();
      }
    } catch (e) {
      print("Erro ao tocar/parar. Desfazendo estado.");
      isPlaying = !isPlaying;
      rotationController.stop();
      notifyListeners();
    }
  }

  Future<void> _playStation() async {
    if (currentStation == null) return;
    
    isBuffering = true;
    notifyListeners();
    
    try {
      await audioPlayer.setUrl(currentStation!.streamUrl);
      await audioPlayer.play();
    } catch (e) {
      print("Erro ao tocar estação: $e");
      throw e; 
    } finally {
      isBuffering = false;
      notifyListeners();
    }
  }

  Future<void> _stopStation() async {
    await audioPlayer.stop();
  }
  
  void nextStation() => _changeStation(currentIndex + 1);
  void previousStation() => _changeStation(currentIndex - 1);
  void selectStation(int index) => _changeStation(index);

  // --- FUNÇÃO CORRIGIDA ---
  Future<void> _changeStation(int newIndex) async {
    if (newIndex < 0 || newIndex >= stations.length || isBuffering) return;

    // 1. Guarda o estado atual do player
    final wasPlaying = isPlaying;

    // Se estava tocando, para o áudio e as animações para não ter sobreposição
    if (wasPlaying) {
      // Apenas para o player, o estado isPlaying e a animação serão tratados pelo playStation
      await _stopStation();
    }

    // 2. Muda para a nova estação
    currentIndex = newIndex;
    
    // Notifica a UI para mostrar a nova arte/nome imediatamente
    notifyListeners();

    // Carrega as informações da nova estação em segundo plano
    await extractDominantColor();
    await _storageService.saveLastStationIndex(currentIndex);

    // 3. Se estava tocando antes, começa a tocar a nova estação automaticamente
    if (wasPlaying) {
      // Reativa o estado de "tocando" e a animação antes de chamar o player
      isPlaying = true;
      rotationController.repeat();
      notifyListeners(); // Garante que o ícone mude para pause, se necessário
      await _playStation();
    }
  }
  // --- FIM DA CORREÇÃO ---

  Future<void> extractDominantColor() async {
    if (currentStation?.artUrl == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(currentStation!.artUrl!),
        maximumColorCount: 20,
      );
      dominantColor = palette.dominantColor?.color ?? const Color(0xFF6C63FF);
      backgroundColor = Color.lerp(dominantColor, Colors.black, 0.85)!;
      notifyListeners();
    } catch (e) {
      print('Erro ao extrair cor: $e');
    }
  }
  
  void animateButtonDown() => buttonScaleController.reverse();
  void animateButtonUp() => buttonScaleController.forward();

  @override
  void dispose() {
    audioPlayer.dispose();
    rotationController.dispose();
    pulseController.dispose();
    buttonScaleController.dispose();
    super.dispose();
  }
}
