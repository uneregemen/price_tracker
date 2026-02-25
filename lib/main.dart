import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ZaraScreen(),
    );
  }
}

class ZaraScreen extends StatefulWidget {
  @override
  _ZaraScreenState createState() => _ZaraScreenState();
}

class _ZaraScreenState extends State<ZaraScreen> {
  TextEditingController linkBox = TextEditingController();
  String image = "";
  String name = "";
  String price = "";
  String cleanPrice = "0";
  String searchedUrl = "";
  String selectedSize = "";
  List<String> sizes = [];
  bool isWaiting = false;

  void fetchDetails() async {
    setState(() {
      isWaiting = true;
      searchedUrl = linkBox.text;
      selectedSize = "";
    });

    try {
      var address = Uri.parse("http://localhost:8080/api/products/preview");
      var response = await http.post(
        address,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"url": searchedUrl}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          image = data["imageUrl"] ?? "";
          name = data["name"] ?? "";
          cleanPrice = data["price"]?.toString() ?? "0";
          price = cleanPrice + " TL";
          
          sizes = [];
          if (data["sizes"] != null) {
            for (var size in data["sizes"]) {
              sizes.add(size.toString());
            }
          }
        });
      } else {
        showError("Not found");
      }
    } catch (e) {
      showError("No internet connection");
    }

    setState(() {
      isWaiting = false;
    });
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: TextStyle(color: Colors.white))));
  }

  void addToList() async {
    if (selectedSize == "") {
      showError("Please select a size");
      return;
    }

    try {
      var address = Uri.parse("http://localhost:8080/api/products/save");
      var response = await http.post(
        address,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "url": searchedUrl,
          "price": double.tryParse(cleanPrice) ?? 0.0,
          "imageUrl": image,
          "targetSize": selectedSize,
          "inStockNotified": false
        }),
      );

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: Text("Success", style: TextStyle(color: Colors.white)),
            content: Text("Added to list", style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK", style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        );
      } else {
        showError("Could not save");
      }
    } catch (e) {
      showError("No internet connection");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.notifications, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => NotificationsScreen()),
            );
          },
        ),
        title: Text("Product Finder", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_bag, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClosetScreen()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: linkBox,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Paste link",
                hintStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
            SizedBox(height: 15),
            isWaiting 
              ? Center(child: CircularProgressIndicator(color: Colors.white))
              : ElevatedButton(
                  onPressed: fetchDetails,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                  child: Text("Find"),
                ),
            SizedBox(height: 25),
            if (image != "") Image.network(image, height: 350, fit: BoxFit.cover),
            SizedBox(height: 20),
            if (name != "") Text(name, style: TextStyle(fontSize: 20, color: Colors.white)),
            SizedBox(height: 8),
            if (price != "") Text(price, style: TextStyle(fontSize: 22, color: Colors.white)),
            SizedBox(height: 20),
            if (sizes.isNotEmpty) ...[
              Text("Select size:", style: TextStyle(fontSize: 16, color: Colors.white54)),
              SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                children: sizes.map((size) {
                  bool inStock = size.contains("Stokta") || size.contains("In Stock");
                  String cleanSize = size.replaceAll("(Stokta)", "").replaceAll("(Tükendi)", "").replaceAll("In Stock", "").replaceAll("Out of Stock", "").trim();
                  return ChoiceChip(
                    label: Text(cleanSize, style: TextStyle(color: Colors.black)),
                    selected: selectedSize == cleanSize,
                    onSelected: (bool selected) {
                      setState(() {
                        selectedSize = selected ? cleanSize : "";
                      });
                    },
                    backgroundColor: inStock ? Colors.green.shade300 : Colors.red.shade300,
                    selectedColor: Colors.blue.shade300,
                  );
                }).toList(),
              ),
            ],
            SizedBox(height: 35),
            if (name != "")
              ElevatedButton(
                onPressed: addToList,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, foregroundColor: Colors.white),
                child: Text("Add to List"),
              ),
          ],
        ),
      ),
    );
  }
}

class ClosetScreen extends StatefulWidget {
  @override
  _ClosetScreenState createState() => _ClosetScreenState();
}

class _ClosetScreenState extends State<ClosetScreen> {
  List items = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchCloset();
  }

  void fetchCloset() async {
    try {
      var address = Uri.parse("http://localhost:8080/api/products/list");
      var response = await http.get(address);
      if (response.statusCode == 200) {
        setState(() {
          items = jsonDecode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void deleteItem(String url) async {
    try {
      String encodedUrl = Uri.encodeComponent(url);
      var address = Uri.parse("http://localhost:8080/api/products/delete?url=$encodedUrl");
      var response = await http.delete(address);
      if (response.statusCode == 200) {
        fetchCloset();
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("My Closet", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                var item = items[index];
                return Card(
                  color: Colors.grey[900],
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: item["imageUrl"] != null 
                        ? Image.network(item["imageUrl"], width: 50, height: 50, fit: BoxFit.cover)
                        : Icon(Icons.image, color: Colors.white),
                    title: Text(item["name"] ?? "", style: TextStyle(color: Colors.white)),
                    subtitle: Text("${item["price"]} TL - Size: ${item["targetSize"] ?? ""}", style: TextStyle(color: Colors.green)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red.shade300),
                      onPressed: () => deleteItem(item["url"]),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List serverNotifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  void fetchNotifications() async {
    try {
      var address = Uri.parse("http://localhost:8080/api/products/notifications");
      var response = await http.get(address);
      if (response.statusCode == 200) {
        setState(() {
          serverNotifications = jsonDecode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Notifications", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : serverNotifications.isEmpty
              ? Center(child: Text("No notifications", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: serverNotifications.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: Colors.grey[900],
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: Icon(Icons.notifications_active, color: Colors.green.shade300),
                        title: Text(serverNotifications[index]["message"] ?? "", style: TextStyle(color: Colors.white)),
                      ),
                    );
                  },
                ),
    );
  }
}