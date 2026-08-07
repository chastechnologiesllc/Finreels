// ── In-app key insights for books that are not freely available online ────────
// Each entry provides real, substantive chapter-by-chapter insights so the
// user gets genuine value. A "Get Full Book" link directs them to purchase.

class BookChapter {
  final String title;
  final String body;
  final List<String> keyPoints;
  const BookChapter({
    required this.title,
    required this.body,
    this.keyPoints = const [],
  });
}

class BookInsightData {
  final String id;
  final String title;
  final String author;
  final String tagline;
  final String intro;
  final List<BookChapter> chapters;
  final String purchaseUrl; // Amazon affiliate or Google Play Books
  const BookInsightData({
    required this.id,
    required this.title,
    required this.author,
    required this.tagline,
    required this.intro,
    required this.chapters,
    required this.purchaseUrl,
  });
}

const List<BookInsightData> kBookInsights = [

  // ── Think and Grow Rich ────────────────────────────────────────────────────
  BookInsightData(
    id: 'book_think_grow',
    title: 'Think and Grow Rich',
    author: 'Napoleon Hill',
    tagline: '13 principles of wealth distilled from 500+ successful people.',
    intro:
        'Napoleon Hill spent 20 years interviewing over 500 of America\'s most '
        'successful people — including Andrew Carnegie, Henry Ford, and Thomas '
        'Edison — to distil the common principles behind extraordinary wealth. '
        'First published in 1937, this book has sold over 100 million copies '
        'and remains one of the best-selling self-help books of all time.',
    chapters: [
      BookChapter(
        title: '1. Thoughts Are Things',
        body:
            'Everything begins with a thought. Edwin C. Barnes had nothing but '
            'a burning desire to work with Edison — no money, no connections. '
            'He hitchhiked to Edison\'s lab and eventually became his partner. '
            'The starting point of all achievement is a definiteness of purpose '
            'backed by a burning desire for its fulfilment.',
        keyPoints: [
          'Desire is the starting point of all achievement',
          'A burning, obsessive goal separates the wealthy from the wishing',
          'Thoughts backed by emotion become reality faster',
        ],
      ),
      BookChapter(
        title: '2. Desire — The First Step to Riches',
        body:
            'Wishing for wealth won\'t cut it. You need a white-hot, specific '
            'desire. Hill\'s six-step method: fix the exact amount you want, '
            'decide what you\'ll give in return, set a definite date, make a '
            'plan, write it all out, and read it aloud twice daily with emotion.',
        keyPoints: [
          'Be specific — "I want more money" is not a desire, it\'s a wish',
          'Read your written desire statement every morning and night',
          'Burn all mental bridges back to average — total commitment',
        ],
      ),
      BookChapter(
        title: '3. Faith — Visualising and Believing',
        body:
            'Faith is a state of mind you can develop through auto-suggestion — '
            'repeated affirmations to your subconscious. When you truly believe '
            'you will achieve something, your mind begins to find paths your '
            'conscious mind would have dismissed. The subconscious cannot tell '
            'the difference between real and vividly imagined experience.',
        keyPoints: [
          'Repeat your goal to yourself with emotion, not just words',
          'Act as if you have already achieved your goal',
          'Self-confidence built through repetition becomes unshakeable',
        ],
      ),
      BookChapter(
        title: '4. Auto-Suggestion — The Medium of Influence',
        body:
            'Your subconscious mind absorbs every thought you feed it. '
            'Auto-suggestion is deliberately programming it. Combine '
            'your written statement with emotion and repetition. Neutral '
            'statements do nothing — the subconscious responds only to thoughts '
            'charged with feeling.',
        keyPoints: [
          'Read your desire statement with genuine emotion',
          'Visualise yourself already in possession of the money',
          'Concentrate on these thoughts just before sleep',
        ],
      ),
      BookChapter(
        title: '5. Specialised Knowledge',
        body:
            'General knowledge is of little use in wealth building. Henry Ford '
            'had barely a primary school education, yet he employed specialists '
            'who knew everything he needed. The secret: know how to acquire and '
            'organise specialised knowledge, not necessarily possess it yourself.',
        keyPoints: [
          'School teaches you how to learn, not necessarily what to earn',
          'Your network of specialists multiplies your own knowledge',
          'Identify the gap in knowledge between you and your goal — then fill it',
        ],
      ),
      BookChapter(
        title: '6. Imagination — The Workshop of the Mind',
        body:
            'Hill distinguishes synthetic imagination (rearranging existing ideas) '
            'from creative imagination (hunches, inspiration from Infinite '
            'Intelligence). Most wealth is built through synthetic imagination — '
            'combining existing products, services, or systems in new ways.',
        keyPoints: [
          'Most fortunes are built by combining old ideas in new ways',
          'Your imagination grows stronger with deliberate use',
          'Ideas are the beginning point of all fortunes',
        ],
      ),
      BookChapter(
        title: '7. Organised Planning',
        body:
            'No individual has sufficient knowledge or effort to build great '
            'wealth alone. The Master Mind — a group of people aligned toward '
            'a single goal — multiplies your brainpower. Every great industrialist '
            'used a Master Mind group. Temporary defeat is not failure; it is '
            'a signal to create a better plan.',
        keyPoints: [
          'Form or join a mastermind group aligned to your goals',
          'Failure is just temporary defeat — change the plan, not the goal',
          'Persistence and definite plans beat talent and luck',
        ],
      ),
      BookChapter(
        title: '8. Decision & Persistence',
        body:
            'Successful people reach decisions promptly and change them slowly. '
            'Unsuccessful people decide slowly and change often. Persistence is '
            'the sustained effort required to accumulate faith. Most people give '
            'up at the first sign of opposition — this is why wealth is rare.',
        keyPoints: [
          'Make decisions quickly and change them slowly',
          'Persistence is to character what carbon is to steel',
          'Most people quit one step before the breakthrough',
        ],
      ),
      BookChapter(
        title: '9. The Subconscious Mind & The Brain',
        body:
            'The subconscious is a broadcasting and receiving station. It works '
            'continuously even while you sleep, connecting your thoughts to '
            'opportunities and people. Positive emotions — desire, faith, love, '
            'enthusiasm — are the fuel. Fear, jealousy, and doubt short-circuit '
            'the whole system.',
        keyPoints: [
          'Feed your subconscious positive, specific thoughts daily',
          'Negative emotions block creative intelligence',
          'Your brain literally picks up on the thoughts of those around you',
        ],
      ),
      BookChapter(
        title: '10. The Sixth Sense',
        body:
            'After mastering all 13 principles, a creative faculty develops — '
            'a form of heightened intuition that warns of danger and reveals '
            'opportunity. Hill called this the Sixth Sense. It is the product '
            'of years of deliberate self-development, not something granted to '
            'a lucky few.',
        keyPoints: [
          'Intuition sharpens as a result of deliberately practising the principles',
          'The 13 principles work together as a single system',
          'Self-mastery, not luck, is the true differentiator',
        ],
      ),
    ],
    purchaseUrl: 'https://www.amazon.com/dp/1585424331',
  ),
];

/// Look up insights by book ID.
BookInsightData? findInsight(String bookId) {
  try {
    return kBookInsights.firstWhere((b) => b.id == bookId);
  } on StateError {
    return null;
  }
}
