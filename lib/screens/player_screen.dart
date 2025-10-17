import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/radio_player_controller.dart';
import 'stations_list_screen.dart';

// A tela agora precisa ser um StatefulWidget para fornecer o TickerProvider (vsync)
// para as animações que estão dentro do controller.
class RadioPlayerScreen extends StatefulWidget {
  const RadioPlayerScreen({super.key});

  @override
  State<RadioPlayerScreen> createState() => _RadioPlayerScreenState();
}

class _RadioPlayerScreenState extends State<RadioPlayerScreen> with TickerProviderStateMixin {
  late final RadioPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Criamos o controller aqui, passando o 'this' como vsync
    _controller = RadioPlayerController(vsync: this);
  }

  @override
  void dispose() {
    // Lembre-se de fazer o dispose do controller
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Usamos o ChangeNotifierProvider para fornecer o controller para a árvore de widgets
    return ChangeNotifierProvider.value(
      value: _controller,
      // O Consumer reconstrói a UI quando o controller notifica sobre mudanças
      child: Consumer<RadioPlayerController>(
        builder: (context, controller, child) {
          // A lógica de carregamento e estado vazio agora é lida do controller
          if (controller.isLoading) {
            return _buildLoadingScreen();
          }

          if (controller.stations.isEmpty) {
            return _buildEmptyScreen(controller);
          }

          // A tela principal é construída com os dados do controller
          return _buildPlayerUI(context, controller);
        },
      ),
    );
  }

  // --- WIDGETS DE UI (movidos para fora do build principal para organização) ---

  Widget _buildPlayerUI(BuildContext context, RadioPlayerController controller) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [controller.backgroundColor, const Color(0xFF0A0E27), Colors.black],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(controller),
              const Spacer(),
              _buildAlbumArt(controller),
              const SizedBox(height: 50),
              _buildStationInfo(controller),
              const SizedBox(height: 12),
              if (controller.isPlaying && !controller.isBuffering)
                _buildPlayingIndicator(controller),
              const Spacer(),
              _buildControls(controller),
              const SizedBox(height: 35),
              _buildStationsListButton(context, controller),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
     return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0A0E27), Colors.black],
            ),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    color: Color(0xFF6C63FF),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: 30),
                Text(
                  'Carregando estações...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildEmptyScreen(RadioPlayerController controller) {
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
                  onPressed: controller.isLoading ? null : () => controller.isLoading = true,
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

  Widget _buildHeader(RadioPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: controller.dominantColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: controller.dominantColor.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.radio, size: 20, color: controller.dominantColor),
                const SizedBox(width: 8),
                const Text('Radio Player', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: controller.dominantColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: controller.dominantColor.withOpacity(0.3), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('${controller.currentIndex + 1}/${controller.stations.length}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: controller.dominantColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(RadioPlayerController controller) {
    return AnimatedBuilder(
      animation: controller.rotationController,
      builder: (context, child) {
        return Transform.rotate(angle: controller.rotationController.value * 2 * 3.14159, child: child);
      },
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: controller.dominantColor.withOpacity(0.6), blurRadius: 60, spreadRadius: 15)],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(140),
              child: controller.currentStation?.artUrl != null
                  ? Image.network(controller.currentStation!.artUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => _buildDefaultArtwork(controller))
                  : _buildDefaultArtwork(controller),
            ),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.5), border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
              child: Center(child: Container(width: 20, height: 20, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white))),
            ),
            if (controller.isBuffering)
              Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withOpacity(0.6)),
                child: Center(child: CircularProgressIndicator(color: controller.dominantColor, strokeWidth: 3)),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDefaultArtwork(RadioPlayerController controller) {
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [controller.dominantColor, controller.dominantColor.withOpacity(0.6)])),
      child: const Center(child: Icon(Icons.radio, size: 120, color: Colors.white)),
    );
  }

  Widget _buildStationInfo(RadioPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Text(controller.currentStation?.name ?? 'Carregando...', textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, height: 1.2)),
          if (controller.currentStation?.location != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on_rounded, size: 18, color: controller.dominantColor.withOpacity(0.8)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(controller.currentStation!.location!, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, maxLines: 1),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayingIndicator(RadioPlayerController controller) {
    return AnimatedBuilder(
      animation: controller.pulseController,
      builder: (context, child) {
        return Opacity(
          opacity: 0.5 + (controller.pulseController.value * 0.5),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(color: controller.dominantColor.withOpacity(0.25), borderRadius: BorderRadius.circular(25), border: Border.all(color: controller.dominantColor.withOpacity(0.4), width: 1.5)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.graphic_eq_rounded, color: controller.dominantColor, size: 18),
                const SizedBox(width: 10),
                Text('Tocando agora', style: TextStyle(color: controller.dominantColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControls(RadioPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMaterialYouButton(controller, icon: Icons.skip_previous_rounded, onPressed: controller.currentIndex > 0 && !controller.isBuffering ? controller.previousStation : null, size: 68),
          _buildMainPlayButton(controller),
          _buildMaterialYouButton(controller, icon: Icons.skip_next_rounded, onPressed: controller.currentIndex < controller.stations.length - 1 && !controller.isBuffering ? controller.nextStation : null, size: 68),
        ],
      ),
    );
  }

  Widget _buildMainPlayButton(RadioPlayerController controller) {
    return GestureDetector(
      onTapDown: (_) { if (!controller.isBuffering) controller.animateButtonDown(); },
      onTapUp: (_) { if (!controller.isBuffering) controller.animateButtonUp(); },
      onTapCancel: controller.animateButtonUp,
      onTap: controller.isBuffering ? null : controller.togglePlayPause,
      child: ScaleTransition(
        scale: controller.buttonScaleController,
        child: Container(
          width: 95, height: 95,
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [controller.dominantColor, controller.dominantColor.withOpacity(0.8)]),
            shape: BoxShape.circle,
            border: Border.all(color: controller.dominantColor.withOpacity(0.5), width: 3),
            boxShadow: [
              BoxShadow(color: controller.dominantColor.withOpacity(0.6), blurRadius: 30, spreadRadius: 5),
              BoxShadow(color: controller.dominantColor.withOpacity(0.3), blurRadius: 60, spreadRadius: 10),
            ],
          ),
          child: controller.isBuffering
              ? const Padding(padding: EdgeInsets.all(25), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3.5))
              : Icon(controller.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 50, color: Colors.white),
        ),
      ),
    );
  }

   Widget _buildMaterialYouButton(RadioPlayerController controller, {required IconData icon, required VoidCallback? onPressed, required double size}) {
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
            color: isEnabled ? controller.dominantColor.withOpacity(0.25) : Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
            border: Border.all(color: isEnabled ? controller.dominantColor.withOpacity(0.5) : Colors.white.withOpacity(0.1), width: 2.5),
            boxShadow: isEnabled ? [BoxShadow(color: controller.dominantColor.withOpacity(0.3), blurRadius: 15, spreadRadius: 1)] : [],
          ),
          child: Icon(icon, size: size * 0.45, color: isEnabled ? controller.dominantColor : Colors.white.withOpacity(0.3)),
        ),
      ),
    );
  }
  
  Widget _buildStationsListButton(BuildContext context, RadioPlayerController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showStationsList(context, controller),
          borderRadius: BorderRadius.circular(32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
            decoration: BoxDecoration(color: controller.dominantColor.withOpacity(0.2), borderRadius: BorderRadius.circular(32), border: Border.all(color: controller.dominantColor.withOpacity(0.4), width: 2)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.queue_music_rounded, size: 24, color: controller.dominantColor),
                const SizedBox(width: 12),
                Text('Ver todas as estações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: controller.dominantColor, letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showStationsList(BuildContext context, RadioPlayerController controller) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => StationsListScreen(
          stations: controller.stations,
          currentIndex: controller.currentIndex,
          onStationSelected: (index) {
            controller.selectStation(index);
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
}
