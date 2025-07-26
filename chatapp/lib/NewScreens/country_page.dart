import 'package:chatapp/Model/country_model.dart';
import 'package:flutter/material.dart';

class CountryPage extends StatefulWidget {
  const CountryPage({super.key, this.setCountryData});
  final Function? setCountryData;

  @override
  State<CountryPage> createState() => _CountryPageState();
}

class _CountryPageState extends State<CountryPage> {
  List<CountryModel> countries = [
    CountryModel(name: "India", code: "+91", flag: "🇮🇳"),
    CountryModel(name: "Pakistan", code: "+92", flag: "🇵🇰"),
    CountryModel(name: "United States", code: "+1", flag: "🇺🇸"),
    CountryModel(name: "South Africa", code: "+27", flag: "🇿🇦"),
    CountryModel(name: "Afghanistan", code: "+93", flag: "🇦🇫"),
    CountryModel(name: "United Kingdom", code: "+44", flag: "🇬🇧"),
    CountryModel(name: "Italy", code: "+39", flag: "🇮🇹"),
    CountryModel(name: "India", code: "+91", flag: "🇮🇳"),
    CountryModel(name: "Pakistan", code: "+92", flag: "🇵🇰"),
    CountryModel(name: "United States", code: "+1", flag: "🇺🇸"),
    CountryModel(name: "South Africa", code: "+27", flag: "🇿🇦"),
    CountryModel(name: "Afghanistan", code: "+93", flag: "🇦🇫"),
    CountryModel(name: "United Kingdom", code: "+44", flag: "🇬🇧"),
    CountryModel(name: "Italy", code: "+39", flag: "🇮🇹"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Country Selection",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.search, color: Colors.teal, size: 28),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: countries.length,
        itemBuilder: (context, index) {
          return card(countries[index]);
        },
      ),
    );
  }

  Widget card(CountryModel country) {
    return InkWell(
      onTap: () {
        widget.setCountryData!(country);
      },
      child: Card(
        margin: EdgeInsets.all(0.15),
        child: Container(
          height: 60,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            children: [
              Text(country.flag ?? ''),
              SizedBox(width: 10),
              Text(
                country.name ?? '',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Container(
                  width: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        country.code ?? '',
                        style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
