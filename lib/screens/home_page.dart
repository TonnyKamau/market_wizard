import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

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
        headers: <String, String>{
          'x-rapidapi-key': apiKey,
          'x-rapidapi-host': 'cnbc.p.rapidapi.com'
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

        // Get market advice for each news item
        for (var newsItem in _newsList) {
          getMarketAdvice(newsItem);
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load news';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> getMarketAdvice(dynamic newsItem) async {
    final generativeModel = GenerativeModel(
        apiKey: dotenv.env['GEMINI_KEY']!, model: 'gemini-1.5-flash');

    try {
      final content = [
        Content.text(
            'Based on the following news article, provide market advice: ${jsonEncode(newsItem)}')
      ];
      final response = await generativeModel.generateContent(
          // Assuming 'predict' is the actual method
          content);
      print(response.text);

      setState(() {
        newsItem['advice'] = response.text ?? 'No advice available';
      });
    } catch (e) {
      setState(() {
        newsItem['advice'] = 'Failed to get market advice: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market News'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage))
              : RefreshIndicator(
                  onRefresh: () => getNews(),
                  child: ListView.builder(
                    itemCount: _newsList.length,
                    itemBuilder: (context, index) {
                      final newsItem = _newsList[index];
                      return Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 5,
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
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  newsItem['shorterHeadline'] ?? 'No subtitle',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  newsItem['description'] ?? 'No description',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (newsItem['advice'] != null)
                                  Container(
                                    padding: const EdgeInsets.all(10.0),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withOpacity(0.1),
                                      border: Border.all(
                                        color: Colors.blueAccent,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      'Advice: ${newsItem['advice']}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.blueAccent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (newsItem['advice'] == null)
                                  const CircularProgressIndicator(),
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
