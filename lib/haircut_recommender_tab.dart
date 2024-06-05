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
          title: Text('Incomplete'),
          content: Text('Please select all options.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
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
          title: Text('Recommended Haircut'),
          content: Text(result['prediction']),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Error'),
          content: Text('Failed to get recommendation.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(options[_currentPage][0]), // Display the title
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: options.length,
        onPageChanged: (index) {
          setState(() {
            _currentPage = index;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: List.generate(
                    options[index].length - 1,
                    (i) => RadioListTile<int>(
                      title: Text(options[index][i + 1]), // Display choice
                      value: i,
                      groupValue: _selectedOptions[index],
                      onChanged: (value) {
                        setState(() {
                          _selectedOptions[index] = value!;
                          if (index < options.length - 1) {
                            _pageController.animateToPage(index + 1,
                                duration: Duration(milliseconds: 500),
                                curve: Curves.easeInOut);
                          }
                        });
                      },
                    ),
                  ),
                ),
                if (index == options.length - 1)
                  ElevatedButton(
                    onPressed: _submit,
                    child: Text('Get Recommendations'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
