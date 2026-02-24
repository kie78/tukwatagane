class BookmarksService {
  static final BookmarksService _instance = BookmarksService._internal();
  factory BookmarksService() => _instance;
  BookmarksService._internal();

  final Set<String> _bookmarkedIds = {};

  bool isBookmarked(String productId) {
    return _bookmarkedIds.contains(productId);
  }

  void toggleBookmark(String productId) {
    if (_bookmarkedIds.contains(productId)) {
      _bookmarkedIds.remove(productId);
    } else {
      _bookmarkedIds.add(productId);
    }
  }

  Set<String> getBookmarkedIds() {
    return Set.from(_bookmarkedIds);
  }
}
