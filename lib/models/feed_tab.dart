enum FeedTab {
  videos,
  shorts,
  blogs,
  books,
}

extension FeedTabLabel on FeedTab {
  String get label {
    switch (this) {
      case FeedTab.videos: return 'Videos';
      case FeedTab.shorts: return 'Shorts';
      case FeedTab.blogs:  return 'Blogs';
      case FeedTab.books:  return 'Books';
    }
  }
}
