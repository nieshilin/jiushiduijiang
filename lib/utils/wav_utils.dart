import 'dart:typed_data';
import 'package:jiudhiduijiang/utils/constants.dart';

/// WAV 文件头构建工具
class WavUtils {
  WavUtils._();

  /// 为 PCM 数据构建完整的 WAV 文件（含 44 字节头）
  static Uint8List buildWav(Uint8List pcmData) {
    final dataLength = pcmData.length;
    final header = _buildWavHeader(dataLength);
    final result = Uint8List(header.length + dataLength);
    result.setRange(0, header.length, header);
    result.setRange(header.length, header.length + dataLength, pcmData);
    return result;
  }

  /// 构建 44 字节 WAV 文件头
  static Uint8List _buildWavHeader(int dataLength) {
    final header = ByteData(44);
    final byteRate = AppConstants.sampleRate *
        AppConstants.numChannels *
        AppConstants.bitsPerSample ~/ 8;
    final blockAlign =
        AppConstants.numChannels * AppConstants.bitsPerSample ~/ 8;

    // RIFF chunk descriptor
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, 36 + dataLength, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt sub-chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6d); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // sub-chunk size
    header.setUint16(20, 1, Endian.little); // audio format (PCM)
    header.setUint16(22, AppConstants.numChannels, Endian.little);
    header.setUint32(24, AppConstants.sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, AppConstants.bitsPerSample, Endian.little);

    // data sub-chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataLength, Endian.little);

    return header.buffer.asUint8List();
  }
}
