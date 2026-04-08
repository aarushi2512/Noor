import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui'; // ✅ Essential for BackdropFilter (Glass Effect)
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:noor_new/theme/app_colors.dart'; // ✅ Import Theme Colors

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final Dio _dio = Dio();
  final ScrollController _scrollController = ScrollController();

  int _page = 1;
  bool _isFetchingMore = false;
  List<Article> _allArticles = [];
  List<Article> _filteredArticles = [];
  bool _isLoading = true;
  bool _isPositiveOnly = true;

  static const List<String> _positiveSignalWords = [
    'wins',
    'won',
    'victory',
    'justice',
    'law passed',
    'policy',
    'reform',
    'empowered',
    'fights back',
    'speaks out',
    'breaks silence',
    'survivor',
    'awarded',
    'recognized',
    'celebrates',
    'success',
    'overcomes',
    'launches',
    'creates',
    'builds',
    'founds',
    'leads',
    'achieves',
    'honored',
    'landmark',
    'historic',
    'change',
    'hope',
    'resilience',
    'strength',
    'bravery',
    'activist',
    'advocates',
    'campaign',
    'movement',
    'safe space',
    'support',
    'healing',
    'recovery',
    'education',
    'awareness',
    'training',
    'workshop',
    'new program',
    'initiative',
    'scholarship',
    'mentorship',
    'leadership',
    'promoted',
    'elected',
    'appointed',
    'first woman',
    'role model',
  ];

  static const List<String> _extremeNegativeWords = [
    'killed',
    'murdered',
    'dead',
    'fatally',
    'corpse',
    'suicide',
    'dies',
  ];

  @override
  void initState() {
    super.initState();
    _fetchNews();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isFetchingMore || _isPositiveOnly) return;
    setState(() => _isFetchingMore = true);
    try {
      final String apiKey = dotenv.env['NEWS_API_KEY'] ?? '';
      if (apiKey.isEmpty) return;

      final response = await _dio.get(
        'https://newsapi.org/v2/everything?'
        'q="women\'s%20rights"%20OR%20"gender%20equality"%20OR%20"female%20empowerment"%20'
        'OR%20"women%20safety"%20OR%20"domestic%20violence"%20OR%20"sexual%20harassment"&'
        'language=en&sortBy=publishedAt&pageSize=20&page=${++_page}&apiKey=$apiKey',
      );

      final articlesJson = response.data['articles'] as List?;
      if (articlesJson == null || articlesJson.isEmpty) return;

      final newArticles = articlesJson
          .map((item) => Article.fromJson(item))
          .where((a) => a.title != null && !a.title!.contains('[Removed]'))
          .toList();

      setState(() {
        _allArticles.addAll(newArticles);
        _applyFilter();
      });
    } finally {
      setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _fetchNews() async {
    try {
      final String apiKey = dotenv.env['NEWS_API_KEY'] ?? '';
      if (apiKey.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('News API key missing!')),
          );
        return;
      }

      final response = await _dio.get(
        'https://newsapi.org/v2/everything?'
        'q="women\'s%20safety"%20OR%20"women\'s%20rights"%20OR%20"female%20empowerment"%20'
        'OR%20"gender%20equality"%20OR%20"women%20leadership"%20OR%20"maternal%20health"%20'
        'OR%20"workplace%20discrimination"%20OR%20"sexual%20harassment"%20'
        'OR%20"domestic%20violence"%20OR%20"legal%20aid%20women"%20'
        'OR%20"education%20for%20girls"%20OR%20"women%20in%20STEM"&'
        'language=en&sortBy=publishedAt&pageSize=50&apiKey=$apiKey',
      );

      final articlesJson = response.data['articles'] as List?;
      if (articlesJson == null) throw Exception('No articles');

      final List<Article> articles = articlesJson
          .map((item) => Article.fromJson(item))
          .where((a) => a.title != null && !a.title!.contains('[Removed]'))
          .toList();

      setState(() {
        _allArticles = articles;
        _applyFilter();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load news: $e')));
    }
  }

  void _applyFilter() {
    if (_isPositiveOnly) {
      _filteredArticles = _allArticles.where((article) {
        final text = '${article.title} ${article.description}'.toLowerCase();
        bool isExtremeNegative = _extremeNegativeWords.any(text.contains);
        if (isExtremeNegative) return false;
        bool hasPositiveSignal = _positiveSignalWords.any(text.contains);
        return hasPositiveSignal;
      }).toList();
    } else {
      _filteredArticles = List.from(_allArticles);
    }
  }

  void _onToggleChanged(bool? newValue) {
    if (newValue != null) {
      setState(() {
        _isPositiveOnly = newValue;
        _applyFilter();
        if (!_isPositiveOnly) {
          _page = 1;
          _fetchNews();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ 1. Define Dynamic Gradient & Glass Colors
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [AppColors.bgDarkStart, AppColors.bgDarkEnd]
          : [AppColors.bgLightStart, AppColors.bgLightEnd],
    );

    final glassColor = isDark ? AppColors.glassDark : AppColors.glassLight;

    final textColorMain = isDark
        ? AppColors.textDarkMain
        : AppColors.textLightMain;
    final textColorSub = isDark
        ? AppColors.textDarkSub
        : AppColors.textLightSub;
    final accentColor = isDark
        ? AppColors.primaryBurgundyDark
        : AppColors.primaryBurgundyLight;
    final borderColor = Colors.white.withOpacity(0.3); // ✅ Crisp glass border

    return Scaffold(
      body: Stack(
        children: [
          // ✅ 2. Full Screen Gradient Background
          Container(decoration: BoxDecoration(gradient: bgGradient)),

          // ✅ 3. Content Layer
          SafeArea(
            child: Column(
              children: [
                // --- Floating Glass Header ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 15,
                        sigmaY: 15,
                      ), // ✅ Strong Blur
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: glassColor, // ✅ Transparent Glass Color
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                isDark ? 0.3 : 0.1,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Women\'s News',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColorMain,
                                letterSpacing: -0.5,
                              ),
                            ),
                            // Compact Toggle
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: CupertinoSlidingSegmentedControl<bool>(
                                groupValue: _isPositiveOnly,
                                thumbColor: accentColor.withOpacity(0.3),
                                children: {
                                  true: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'Positive',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isPositiveOnly
                                            ? accentColor
                                            : textColorSub,
                                      ),
                                    ),
                                  ),
                                  false: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      'All',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: !_isPositiveOnly
                                            ? accentColor
                                            : textColorSub,
                                      ),
                                    ),
                                  ),
                                },
                                onValueChanged: _onToggleChanged,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // --- Glass News List ---
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: accentColor),
                        )
                      : RefreshIndicator(
                          color: accentColor,
                          backgroundColor: glassColor,
                          onRefresh: () async => _fetchNews(),
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount:
                                _filteredArticles.length +
                                (_isFetchingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _filteredArticles.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 20,
                                    bottom: 20,
                                  ),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: accentColor.withOpacity(0.5),
                                    ),
                                  ),
                                );
                              }
                              final article = _filteredArticles[index];
                              final formattedDate = _formatDate(
                                article.publishedAt,
                              );

                              return GestureDetector(
                                onTap: () => _launchUrl(article.url),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(
                                          isDark ? 0.4 : 0.1,
                                        ),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ), // ✅ Glass Blur on Card
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color:
                                              glassColor, // ✅ Transparent Glass Fill
                                          border: Border.all(
                                            color: borderColor,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Image
                                            if (article.urlToImage != null &&
                                                article.urlToImage!.isNotEmpty)
                                              CachedNetworkImage(
                                                imageUrl: article.urlToImage!,
                                                height: 180,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    Container(
                                                      height: 180,
                                                      color: Colors.grey
                                                          .withOpacity(0.2),
                                                      child: Icon(
                                                        CupertinoIcons.news,
                                                        size: 48,
                                                        color: textColorSub,
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (
                                                      context,
                                                      url,
                                                      error,
                                                    ) => Container(
                                                      height: 180,
                                                      color: Colors.grey
                                                          .withOpacity(0.2),
                                                      child: Icon(
                                                        CupertinoIcons
                                                            .exclamationmark_triangle,
                                                        size: 48,
                                                        color: textColorSub,
                                                      ),
                                                    ),
                                              ),

                                            // Content
                                            Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    article.title ?? 'Untitled',
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: textColorMain,
                                                      height: 1.3,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  if (article.description !=
                                                          null &&
                                                      article
                                                          .description!
                                                          .isNotEmpty)
                                                    Text(
                                                      article.description!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: textColorSub,
                                                        height: 1.4,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.newspaper,
                                                            size: 14,
                                                            color: accentColor,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            article
                                                                    .source
                                                                    ?.name ??
                                                                'Unknown',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color:
                                                                  textColorSub,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        formattedDate,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: textColorSub
                                                              .withOpacity(0.7),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return '';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd MMM').format(date.toLocal());
    } catch (e) {
      return '';
    }
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }
}

// --- Models ---
class Article {
  final Source? source;
  final String? author;
  final String? title;
  final String? description;
  final String? url;
  final String? urlToImage;
  final String? publishedAt;
  final String? content;

  Article({
    this.source,
    this.author,
    this.title,
    this.description,
    this.url,
    this.urlToImage,
    this.publishedAt,
    this.content,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      source: json['source'] != null ? Source.fromJson(json['source']) : null,
      author: json['author'],
      title: json['title'],
      description: json['description'],
      url: json['url'],
      urlToImage: json['urlToImage'],
      publishedAt: json['publishedAt'],
      content: json['content'],
    );
  }
}

class Source {
  final String? id;
  final String? name;
  Source({this.id, this.name});
  factory Source.fromJson(Map<String, dynamic> json) =>
      Source(id: json['id'], name: json['name']);
}
