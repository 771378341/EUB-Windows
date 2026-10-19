/// Client-side filtering of the category labels supplied by the video source.
/// Titles and plot text are deliberately not used as category labels.
class FamilyContentPolicy {
  static bool allowsCategory(String label) {
    final normalized = label.replaceAll(RegExp(r'\s+'), '').replaceAll('倫理', '伦理');
    return !normalized.contains('伦理');
  }

  static bool allowsLabels(Iterable<String> labels) => labels.every(allowsCategory);
}
