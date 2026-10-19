/// 弹幕数据类型
enum DanmakuType {
  scroll, // 滚动（从右向左）
  top, // 顶部固定
  bottom, // 底部固定
}

/// 单条弹幕
class DanmakuItem {
  final String id;
  final String text;
  final int timeMs; // 在视频中的出现时间点（毫秒）
  final int color; // ARGB
  final DanmakuType type;

  const DanmakuItem({
    required this.id,
    required this.text,
    required this.timeMs,
    this.color = 0xFFFFFFFF,
    this.type = DanmakuType.scroll,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'timeMs': timeMs,
    'color': color,
    'type': type.index,
  };

  factory DanmakuItem.fromJson(Map<String, dynamic> json) {
    final typeIndex = (json['type'] as num?)?.toInt() ?? 0;
    return DanmakuItem(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timeMs: (json['timeMs'] as num?)?.toInt() ?? 0,
      color: (json['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
      type:
          DanmakuType.values[typeIndex.clamp(0, DanmakuType.values.length - 1)],
    );
  }
}
