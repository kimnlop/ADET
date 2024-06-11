// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, prefer_final_fields, use_key_in_widget_constructors, library_private_types_in_public_api, unused_field

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class HaircutRecommenderTab extends StatefulWidget {
  @override
  _HaircutRecommenderTabState createState() => _HaircutRecommenderTabState();
}

class _HaircutRecommenderTabState extends State<HaircutRecommenderTab> {
  PageController _pageController = PageController();
  int _currentPage = 0;
  List<List<String>> options = [
    ['Gender Haircut', 'Male', 'Female'],
    ['Hair Length', 'Short', 'Medium', 'Long'],
    ['Face Shape', 'Oval', 'Round', 'Square', 'Heart', 'Diamond'],
    ['Hair Type', 'Straight', 'Wavy', 'Curly'],
    ['Hair Density', 'Thin', 'Medium', 'Thick'],
    ['Recommendations']
  ];
  List<int> _selectedOptions =
      List.filled(5, -1); // Initialize all selections as -1

  void _submit() async {
    if (_selectedOptions.contains(-1)) {
      // Show an alert if not all options are selected
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Incomplete'),
          content: const Text('Please select all options.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Prepare the data to be sent to the backend
    Map<String, String> data = {
      'Gender Haircut': options[0][_selectedOptions[0] + 1],
      'Hair Length': options[1][_selectedOptions[1] + 1],
      'Face Shape': options[2][_selectedOptions[2] + 1],
      'Hair Type': options[3][_selectedOptions[3] + 1],
      'Hair Density': options[4][_selectedOptions[4] + 1],
    };

    final response = await http.post(
      Uri.parse('http://192.168.100.7:5001/predict'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'features': data}),
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Recommended Haircut'),
          content: Text(result['prediction']),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to get recommendation.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100]
                  ?.withOpacity(0.6), // Background with 60% opacity
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: PageView.builder(
              controller: _pageController,
              itemCount: options.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 100), // Space for uniform alignment
                    Center(
                      child: Text(
                        options[index][0],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color.fromRGBO(230, 72, 111, 1),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(
                      options[index].length - 1,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedOptions[index] = i;
                              if (index < options.length - 1) {
                                _pageController.animateToPage(index + 1,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut);
                              }
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: _selectedOptions[index] == i
                                  ? const Color.fromRGBO(254, 173, 86, 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedOptions[index] == i
                                    ? const Color.fromRGBO(230, 72, 111, 1)
                                    : Colors.grey[300]!,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              options[index][i + 1],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color.fromRGBO(230, 72, 111, 1),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (index == options.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 20.0),
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color.fromRGBO(230, 72, 111, 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Get Recommendations',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: HaircutRecommenderTab(),
    theme: ThemeData(
      primarySwatch: Colors.deepPurple,
      scaffoldBackgroundColor: Colors.grey[100],
      textTheme: const TextTheme(
        bodyText2: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    ),
  ));
}
