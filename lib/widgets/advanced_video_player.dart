import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:eduverse/utils/app_theme.dart';

/// Advanced Video Player with YouTube-like controls
/// Features: Play/Pause, Skip 10s, Progress bar, Fullscreen, Speed control
class AdvancedVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String? videoTitle;
  final VoidCallback? onVideoComplete;
  final Function(Duration position)? onPositionChanged;
  final Duration? startPosition;
  final int videoIndex;
  final int totalVideos;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;

  const AdvancedVideoPlayer({
    super.key,
    required this.videoUrl,
    this.videoTitle,
    this.onVideoComplete,
    this.onPositionChanged,
    this.startPosition,
    this.videoIndex = 0,
    this.totalVideos = 1,
    this.onNext,
    this.onPrevious,
  });

  @override
  State<AdvancedVideoPlayer> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<AdvancedVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  bool _isFullscreen = false;
  bool _isBuffering = false;
  Timer? _hideControlsTimer;
  double _playbackSpeed = 1.0;
  bool _hasMarkedComplete = false;

  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(AdvancedVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializePlayer();
    }
  }

  void _initializePlayer() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
          // Seek to start position if provided
          if (widget.startPosition != null) {
            _controller.seekTo(widget.startPosition!);
          }
          _controller.addListener(_videoListener);
        }
      }).catchError((error) {
        debugPrint('Video initialization error: $error');
      });
  }

  void _videoListener() {
    if (!mounted) return;
    
    // Check for buffering
    final isBuffering = _controller.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }

    // Report position changes
    widget.onPositionChanged?.call(_controller.value.position);

    // Mark complete after 30 seconds of watching
    if (!_hasMarkedComplete && _controller.value.position.inSeconds >= 30) {
      _hasMarkedComplete = true;
      // The parent can track this through onPositionChanged
    }

    // Check if video ended
    if (_controller.value.position >= _controller.value.duration &&
        _controller.value.duration > Duration.zero) {
      widget.onVideoComplete?.call();
    }

    setState(() {});
  }

  void _disposeController() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _disposeController();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
      _startHideControlsTimer();
    }
    setState(() {});
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (_controller.value.isPlaying && mounted) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onTapVideo() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _controller.value.isPlaying) {
      _startHideControlsTimer();
    }
  }

  void _skipForward() {
    final newPosition = _controller.value.position + const Duration(seconds: 10);
    _controller.seekTo(newPosition);
  }

  void _skipBackward() {
    final newPosition = _controller.value.position - const Duration(seconds: 10);
    _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  void _showSpeedDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Playback Speed',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._speedOptions.map((speed) => ListTile(
              leading: Icon(
                speed == _playbackSpeed ? Icons.check_circle : Icons.circle_outlined,
                color: speed == _playbackSpeed ? AppTheme.primaryColor : Colors.grey,
              ),
              title: Text(
                '${speed}x',
                style: TextStyle(
                  fontWeight: speed == _playbackSpeed ? FontWeight.bold : FontWeight.normal,
                  color: speed == _playbackSpeed ? AppTheme.primaryColor : Colors.black,
                ),
              ),
              onTap: () {
                setState(() => _playbackSpeed = speed);
                _controller.setPlaybackSpeed(speed);
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return GestureDetector(
      onTap: _onTapVideo,
      child: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

            // Buffering indicator
            if (_isBuffering)
              const CircularProgressIndicator(color: Colors.white),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: _buildControlsOverlay(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    final progress = duration.inMilliseconds > 0
        ? position.inMilliseconds / duration.inMilliseconds
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top bar
          _buildTopBar(),
          
          // Center controls
          _buildCenterControls(),
          
          // Bottom bar with progress
          _buildBottomBar(position, duration, progress),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (widget.videoTitle != null)
            Expanded(
              child: Text(
                widget.videoTitle!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          // Speed button
          _buildControlButton(
            icon: Icons.speed,
            label: '${_playbackSpeed}x',
            onTap: _showSpeedDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous video
        if (widget.totalVideos > 1 && widget.videoIndex > 0)
          _buildCircleButton(
            icon: Icons.skip_previous,
            size: 40,
            onTap: widget.onPrevious,
          ),
        
        const SizedBox(width: 20),
        
        // Skip backward
        _buildCircleButton(
          icon: Icons.replay_10,
          size: 48,
          onTap: _skipBackward,
        ),
        
        const SizedBox(width: 20),
        
        // Play/Pause
        _buildCircleButton(
          icon: _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          size: 64,
          filled: true,
          onTap: _togglePlayPause,
        ),
        
        const SizedBox(width: 20),
        
        // Skip forward
        _buildCircleButton(
          icon: Icons.forward_10,
          size: 48,
          onTap: _skipForward,
        ),
        
        const SizedBox(width: 20),
        
        // Next video
        if (widget.totalVideos > 1 && widget.videoIndex < widget.totalVideos - 1)
          _buildCircleButton(
            icon: Icons.skip_next,
            size: 40,
            onTap: widget.onNext,
          ),
      ],
    );
  }

  Widget _buildBottomBar(Duration position, Duration duration, double progress) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: AppTheme.accentColor,
              inactiveTrackColor: Colors.white30,
              thumbColor: AppTheme.accentColor,
              overlayColor: AppTheme.accentColor.withOpacity(0.3),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) {
                final newPosition = Duration(
                  milliseconds: (value * duration.inMilliseconds).toInt(),
                );
                _controller.seekTo(newPosition);
              },
            ),
          ),
          
          // Time and controls row
          Row(
            children: [
              // Time
              Text(
                '${_formatDuration(position)} / ${_formatDuration(duration)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              
              const Spacer(),
              
              // Video index
              if (widget.totalVideos > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Video ${widget.videoIndex + 1}/${widget.totalVideos}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ),
              
              const SizedBox(width: 12),
              
              // Fullscreen button
              GestureDetector(
                onTap: _toggleFullscreen,
                child: Icon(
                  _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required double size,
    bool filled = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled ? Colors.white : Colors.white24,
        ),
        child: Icon(
          icon,
          color: filled ? AppTheme.primaryColor : Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
