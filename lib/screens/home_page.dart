import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<dynamic> _newsList = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    getNews();
  }

  Future<void> getNews() async {
    final String apiKey = dotenv.env['API_KEY']!;
    try {
      final response = await http.get(
        Uri.parse('https://cnbc.p.rapidapi.com/news/v2/list-special-reports'),
        headers: {
          'x-rapidapi-key': apiKey,
          'x-rapidapi-host': 'cnbc.p.rapidapi.com',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final filteredNews = data['data']['specialReportsEntries']['results']
                ?.where((item) =>
                    item['__typename'] != 'partnerstory' &&
                    item['__typename'] != 'cnbcvideo')
                .toList() ??
            [];

        setState(() {
          _newsList = filteredNews;
          _isLoading = false;
          _errorMessage = '';
        });

        for (var newsItem in _newsList) {
          getMarketAdvice(newsItem);
        }
      } else {
        _setError('Failed to load news');
      }
    } catch (e) {
      _setError('An error occurred: $e');
    }
  }

  Future<void> getMarketAdvice(dynamic newsItem) async {
    final generativeModel = GenerativeModel(
        apiKey: dotenv.env['GEMINI_KEY']!, model: 'gemini-1.5-flash');

    try {
      final content = [
        Content.text(
            'Provide a brief market advice based on this news article: ${jsonEncode(newsItem)}. Keep it under 100 words.')
      ];
      final response = await generativeModel.generateContent(content);
      String advice = response.text ?? 'No advice available';
      advice = advice.replaceAll(RegExp(r'##\s*'), '');
      advice = advice.replaceAll(RegExp(r'\*\*\s*'), '');
      advice = advice.replaceAll(RegExp(r'\* '), '• ');

      setState(() {
        newsItem['advice'] = advice;
      });
    } catch (e) {
      setState(() {
        newsItem['advice'] = 'Failed to get market advice: $e';
      });
    }
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message;
      _isLoading = false;
    });
  }

  Widget buildAdviceWidget(String advice) {
    final isAdviceAvailable = !advice.startsWith('Failed to get market advice');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SelectableText(
          advice,
          textAlign: TextAlign.justify,
          style: const TextStyle(fontSize: 16, color: Colors.black),
        ),
        if (isAdviceAvailable)
          Positioned(
            bottom: -6,
            right: -6,
            child: IconButton(
              iconSize: 25,
              icon: const Icon(Icons.copy, color: Colors.grey),
              onPressed: () => _copyToClipboard(advice),
            ),
          ),
      ],
    );
  }

  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: 'Copied to clipboard',
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.grey[700],
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Market News',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 40),
                      Text(
                        _errorMessage,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: getNews,
                  color: Colors.blueAccent,
                  child: ListView.builder(
                    itemCount: _newsList.length,
                    itemBuilder: (context, index) {
                      final newsItem = _newsList[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  newsItem['headline'] ?? 'No title',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  newsItem['description'] ?? 'No description',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 10),
                                if (newsItem['advice'] != null)
                                  Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      border:
                                          Border.all(color: Colors.blueAccent),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child:
                                        buildAdviceWidget(newsItem['advice']),
                                  ),
                                if (newsItem['advice'] == null)
                                  Lottie.asset(
                                    'assets/loading.json',
                                    height: 100,
                                    width: 100,
                                    fit: BoxFit.contain,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
