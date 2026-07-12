import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';

import 'package:jiudhiduijiang/utils/constants.dart';
import 'package:jiudhiduijiang/utils/wav_utils.dart';

// Opus 编解码
import 'package:opus_dart/opus_dart.dart';

/// 音频录制与播放服务 — Opus 编解码
///
/// 录音：PCM16 → 累积 20ms 帧 → Opus 编码 → onAudioData(opusData)
/// 播放：enqueueAudioData(opusData) → Opus 解码 → PCM16 → WAV → 播放
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  late final AudioPlayer _player;

  StreamSubscription? _recordSub;
  bool _isRecording = false;
  bool _isMuted = false;
  double _volume = 0.7;

  // ── Opus 编解码器 ──
  SimpleOpusEncoder? _opusEncoder;
  SimpleOpusDecoder? _opusDecoder;

  // 录音 PCM 累积缓冲（等待凑齐一帧再编码）
  final List<int> _pcmAccumulator = [];
  bool _firstDataLogged = false;

  // 语音数据发送回调 — 输出 Opus 编码后的数据
  void Function(Uint8List opusData)? onAudioData;

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

  /// 配置播放器音频上下文 — 使用 playAndRecord 支持同时录音和播放
  ///
  /// iOS 关键：必须用 playAndRecord 而非 playback，否则 record 包
  /// 无法激活麦克风输入（playback 仅允许输出方向）。
  Future<void> _configureAudioContext() async {
    try {
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            audioMode: AndroidAudioMode.inCommunication,
            audioFocus: AndroidAudioFocus.gain,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.voiceCommunication,
            stayAwake: true,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: const {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.allowBluetooth,
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

  /// 确保 Opus 编码器已创建
  void _ensureEncoder() {
    if (kIsWeb) return;
    if (_opusEncoder != null) return;
    try {
      _opusEncoder = SimpleOpusEncoder(
        sampleRate: AppConstants.sampleRate,
        channels: AppConstants.numChannels,
        application: Application.voip,
      );
      _log('Opus 编码器已创建 (VoIP, ${AppConstants.sampleRate}Hz)');
    } catch (e) {
      _log('Opus 编码器创建失败: $e');
    }
  }

  /// 确保 Opus 解码器已创建
  void _ensureDecoder() {
    if (kIsWeb) return;
    if (_opusDecoder != null) return;
    try {
      _opusDecoder = SimpleOpusDecoder(
        sampleRate: AppConstants.sampleRate,
        channels: AppConstants.numChannels,
      );
      _log('Opus 解码器已创建 (${AppConstants.sampleRate}Hz)');
    } catch (e) {
      _log('Opus 解码器创建失败: $e');
    }
  }

  /// 开始录音（PTT按下时调用）
  Future<void> startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _log('❌ 录音失败：无麦克风权限');
      return;
    }

    _ensureEncoder();
    if (_opusEncoder == null) {
      _log('❌ 录音失败：Opus 编码器创建失败');
      return;
    }
    _log('🎤 开始录音... (编码器就绪, ${AppConstants.sampleRate}Hz)');
    _pcmAccumulator.clear();

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
      _firstDataLogged = false;
      _recordSub = stream.listen((Uint8List data) {
        _onRecordData(data);
      }, onError: (e) {
        _log('❌ 录音流错误: $e');
        _isRecording = false;
      });
      _log('✅ 录音流已启动');
    } catch (e) {
      _isRecording = false;
      _log('❌ 启动录音流异常: $e');
      rethrow;
    }
  }

  /// 处理录音 PCM 数据 — 累积到完整帧后 Opus 编码
  void _onRecordData(Uint8List data) {
    if (_isMuted || onAudioData == null) return;
    if (_opusEncoder == null || _opusEncoder!.destroyed) return;

    if (!_firstDataLogged) {
      _firstDataLogged = true;
      _log('📥 收到 PCM 数据: ${data.length} bytes');
    }

    _pcmAccumulator.addAll(data);

    // 每凑齐一帧 (640 bytes = 320 samples = 20ms) 编码一次
    while (_pcmAccumulator.length >= AppConstants.opusFrameBytes) {
      final frameBytes =
          Uint8List.fromList(_pcmAccumulator.sublist(0, AppConstants.opusFrameBytes));
      _pcmAccumulator.removeRange(0, AppConstants.opusFrameBytes);

      // Uint8List → Int16List (PCM16 little-endian)
      final pcmSamples = frameBytes.buffer.asInt16List();

      try {
        final opusData = _opusEncoder!.encode(input: pcmSamples);
        if (opusData.isNotEmpty) {
          onAudioData!(opusData);
        }
      } catch (e) {
        _log('❌ Opus 编码失败: $e');
      }
    }
  }

  /// 停止录音（PTT松开时调用）
  Future<void> stopRecording() async {
    if (!_isRecording) return;
    _isRecording = false;
    await _recordSub?.cancel();
    _recordSub = null;
    await _recorder.stop();

    // 编码剩余不足一帧的 PCM（填充零到完整帧）
    if (_pcmAccumulator.isNotEmpty &&
        _opusEncoder != null &&
        !_opusEncoder!.destroyed &&
        !_isMuted &&
        onAudioData != null) {
      final padded = Uint8List(AppConstants.opusFrameBytes);
      final remaining = _pcmAccumulator.length;
      if (remaining <= AppConstants.opusFrameBytes) {
        padded.setRange(0, remaining, _pcmAccumulator);
      }
      _pcmAccumulator.clear();

      try {
        final pcmSamples = padded.buffer.asInt16List();
        final opusData = _opusEncoder!.encode(input: pcmSamples);
        if (opusData.isNotEmpty) {
          onAudioData!(opusData);
        }
      } catch (_) {}
    }
  }

  /// 接收 Opus 语音数据并解码播放
  void enqueueAudioData(String senderIp, Uint8List opusData) {
    if (_isMuted || opusData.isEmpty) return;

    _ensureDecoder();
    if (_opusDecoder == null || _opusDecoder!.destroyed) return;

    // Opus → PCM16
    Int16List pcmSamples;
    try {
      pcmSamples = _opusDecoder!.decode(input: opusData);
    } catch (e) {
      _log('Opus 解码失败: $e');
      return;
    }

    // Int16List → Uint8List (PCM16 little-endian)
    final pcmBytes = pcmSamples.buffer.asUint8List(
      pcmSamples.offsetInBytes,
      pcmSamples.lengthInBytes,
    );

    // 加入播放缓冲
    final buffer = _pcmBuffers[senderIp] ?? <int>[];
    buffer.addAll(pcmBytes);
    _pcmBuffers[senderIp] = buffer;

    if (_playbackFlushTimer == null) {
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

      final minBytes = force ? 1 : 6400; // 200ms @ 16kHz 16bit mono
      if (buffer.length < minBytes) continue;

      final pcmBytes = Uint8List.fromList(buffer);
      buffer.clear();

      final wavBytes = WavUtils.buildWav(pcmBytes);
      _playbackQueue.add(wavBytes);
    }

    _tryPlayNext();

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
    _opusEncoder?.destroy();
    _opusEncoder = null;
    _opusDecoder?.destroy();
    _opusDecoder = null;
    _recorder.dispose();
    _player.dispose();
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[AudioService] $msg');
  }
}
