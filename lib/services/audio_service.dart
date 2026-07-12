import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';

import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/utils/wav_utils.dart';

/// 音频录制与播放服务
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  late final AudioPlayer _player;

  StreamSubscription? _recordSub;
  bool _isRecording = false;
  bool _isMuted = false;
  double _volume = 0.7;

  // 语音数据发送回调
  void Function(Uint8List pcmData)? onAudioData;

  // 播放队列
  final List<Uint8List> _playbackQueue = [];
  bool _isPlaying = false;
  // 按发送者IP分组的PCM缓冲
  final Map<String, List<int>> _pcmBuffers = {};
  Timer? _playbackFlushTimer;

  bool get isRecording => _isRecording;
  bool get isMuted => _isMuted;
  double get volume => _volume;

  AudioService() {
    _player = AudioPlayer();
    _configureAudioContext();
    _player.setReleaseMode(ReleaseMode.stop);
    _player.onPlayerComplete.listen((_) {
      _isPlaying = false;
      _tryPlayNext();
    });
    _player.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        _isPlaying = false;
        _tryPlayNext();
      }
    });
  }

  /// 配置播放器音频上下文 — 强制走扬声器输出
  Future<void> _configureAudioContext() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            // 用 normal 模式走扬声器，inCommunication 会路由到听筒
            isSpeakerphoneOn: true,
            audioMode: AndroidAudioMode.normal,
            audioFocus: AndroidAudioFocus.gain,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.media,
            stayAwake: true,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
            },
          ),
        ),
      );
      await _player.setVolume(_isMuted ? 0 : _volume);
    } catch (e) {
      _log('音频上下文配置失败: $e');
    }
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    return await _recorder.hasPermission();
  }

  /// 开始录音（PTT按下时调用）
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    try {
      final stream = await _recorder.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          bitRate: 256000,
          sampleRate: AppConstants.sampleRate,
          numChannels: AppConstants.numChannels,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
      );

      _isRecording = true;
      _recordSub = stream.listen((Uint8List data) {
        if (!_isMuted && onAudioData != null) {
          onAudioData!(data);
        }
      }, onError: (e) {
        _log('录音错误: $e');
      });
    } catch (e) {
      _isRecording = false;
      rethrow;
    }
  }

  /// 停止录音（PTT松开时调用）
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _recordSub?.cancel();
    _recordSub = null;
    await _recorder.stop();
  }

  /// 接收语音数据并加入播放缓冲
  void enqueueAudioData(String senderIp, Uint8List pcmData) {
    if (_isMuted) return;

    final buffer = _pcmBuffers[senderIp] ?? <int>[];
    buffer.addAll(pcmData);
    _pcmBuffers[senderIp] = buffer;

    // 用定时器统一刷新，不在每次收到数据时都触发
    if (_playbackFlushTimer == null) {
      // 首次收到数据，立即播放一次（缩短延迟）
      _flushPlaybackBuffer(force: true);
      _playbackFlushTimer = Timer.periodic(
        const Duration(milliseconds: 100),
        (_) => _flushPlaybackBuffer(),
      );
    }
  }

  /// 将缓冲的 PCM 数据转为 WAV 并加入播放队列
  void _flushPlaybackBuffer({bool force = false}) {
    for (final entry in _pcmBuffers.entries) {
      final buffer = entry.value;
      if (buffer.isEmpty) continue;

      // 强制模式：有数据就播；普通模式：积累到 200ms 再播，减少碎片
      final minBytes = force ? 1 : 6400; // 200ms @ 16kHz 16bit mono
      if (buffer.length < minBytes) continue;

      final pcmBytes = Uint8List.fromList(buffer);
      buffer.clear();

      final wavBytes = WavUtils.buildWav(pcmBytes);
      _playbackQueue.add(wavBytes);
    }

    _tryPlayNext();

    // 如果所有缓冲都已清空，停止定时器
    final allEmpty = _pcmBuffers.values.every((b) => b.isEmpty);
    if (allEmpty && _playbackQueue.isEmpty) {
      _playbackFlushTimer?.cancel();
      _playbackFlushTimer = null;
    }
  }

  /// 尝试播放队列中的下一段音频
  Future<void> _tryPlayNext() async {
    if (_isPlaying || _playbackQueue.isEmpty) return;
    _isPlaying = true;
    final wavBytes = _playbackQueue.removeAt(0);
    try {
      await _player.setVolume(_isMuted ? 0 : _volume);
      await _player.play(BytesSource(wavBytes));
      _log('播放音频块: ${wavBytes.length} 字节, 队列剩余 ${_playbackQueue.length}');
    } catch (e) {
      _isPlaying = false;
      _log('播放失败: $e');
      _tryPlayNext();
    }
  }

  /// 通话开始 — 准备接收
  void onVoiceStartReceived(String senderIp) {
    _pcmBuffers[senderIp] = <int>[];
  }

  /// 通话结束 — 刷新剩余缓冲
  void onVoiceEndReceived(String senderIp) {
    // 刷新该发送者的剩余数据
    final buffer = _pcmBuffers[senderIp];
    if (buffer != null && buffer.isNotEmpty) {
      final pcmBytes = Uint8List.fromList(buffer);
      buffer.clear();
      final wavBytes = WavUtils.buildWav(pcmBytes);
      _playbackQueue.add(wavBytes);
      _tryPlayNext();
    }
  }

  /// 设置音量 (0.0 ~ 1.0)
  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _player.setVolume(_isMuted ? 0 : _volume);
  }

  /// 设置静音
  Future<void> setMuted(bool muted) async {
    _isMuted = muted;
    await _player.setVolume(muted ? 0 : _volume);
  }

  /// 停止所有播放
  Future<void> stopPlayback() async {
    _playbackQueue.clear();
    _pcmBuffers.clear();
    _playbackFlushTimer?.cancel();
    _playbackFlushTimer = null;
    _isPlaying = false;
    await _player.stop();
  }

  /// 释放资源
  Future<void> dispose() async {
    await stopRecording();
    await stopPlayback();
    _recorder.dispose();
    _player.dispose();
  }

  void _log(String msg) {
    // 调试日志，release 模式可移除
    // ignore: avoid_print
    print('[AudioService] $msg');
  }
}
