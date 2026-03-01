import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; 
import 'config.dart';

void main() async {
  // Flutter motorunu dış servislere (Firebase'e) hazırlıyoruz
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

 // Bildirim göndermek için kullanıcıdan izin istiyoruz
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Token alma işlemini try-catch içine alıyoruz ki simülatörde uygulama çakılmasın
  try {
    // Apple'ın APNs token'ı vermesi bazen gecikebiliyor, kısa bir bekleme süresi koymak iyi bir taktiktir
    await Future.delayed(const Duration(seconds: 2)); 
    String? token = await messaging.getToken();
    print("🔥 CİHAZ TOKEN NUMARASI (FCM): $token");
  } catch (e) {
    print("⚠️ Token alınamadı (iOS Simülatör kısıtlaması): $e");
  }

  // Kendi uygulamanı başlattığın satır
  runApp(MyApp());

  // Kendi uygulamanı başlattığın satır 
  runApp(MyApp()); 
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthScreen(),
    );
  }
}

// --- GİRİŞ / KAYIT EKRANI ---
class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true; 
  bool isLoading = false;
  
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  void authenticate() async {
    setState(() { isLoading = true; });

    // --- 1. YENİ EKLENEN KISIM: FCM Token'ı Firebase'den Alıyoruz ---
    String? fcmToken = "";
    try {
      fcmToken = await FirebaseMessaging.instance.getToken();
      print("Giriş yaparken alınan Token: $fcmToken");
    } catch (e) {
      print("Token alınamadı: $e");
    }
    // ----------------------------------------------------------------

    String endpoint = isLogin ? "login" : "register";
    var address = Uri.parse("${ApiConfig.baseUrl}/auth/$endpoint");

    try {
      var response = await http.post(
        address,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": usernameController.text,
          "password": passwordController.text,
          "fcmToken": fcmToken // --- 2. YENİ EKLENEN KISIM: Token'ı Java'ya Gönderiyoruz ---
        }),
      );

      if (response.statusCode == 200) {
        if (isLogin) {
          int userId = int.parse(response.body);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ZaraScreen(userId: userId)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kayıt başarılı! Lütfen giriş yapın.")));
          setState(() { isLogin = true; });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.body)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Bağlantı hatası!")));
    }

    setState(() { isLoading = false; });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isLogin ? "Giriş Yap" : "Kayıt Ol",
                style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 40),
              TextField(
                controller: usernameController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Kullanıcı Adı",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Şifre",
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                ),
              ),
              SizedBox(height: 30),
              isLoading 
                ? CircularProgressIndicator(color: Colors.white)
                : ElevatedButton(
                    onPressed: authenticate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, 
                      foregroundColor: Colors.black,
                      minimumSize: Size(double.infinity, 50)
                    ),
                    child: Text(isLogin ? "Giriş" : "Kayıt Ol", style: TextStyle(fontSize: 18)),
                  ),
              SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  setState(() { isLogin = !isLogin; });
                },
                child: Text(
                  isLogin ? "Hesabın yok mu? Kayıt Ol" : "Zaten hesabın var mı? Giriş Yap",
                  style: TextStyle(color: Colors.blue.shade300),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- ANA ARAMA EKRANI ---
class ZaraScreen extends StatefulWidget {
  final int userId; 
  ZaraScreen({required this.userId}); 

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
  bool isSelectedSizeInStock = false;

  void fetchDetails() async {
    setState(() {
      isWaiting = true;
      searchedUrl = linkBox.text;
      selectedSize = "";
    });

    try {
      var address = Uri.parse("${ApiConfig.baseUrl}/products/preview");
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

  void showTopNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150, 
          left: 20, 
          right: 20
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void addToList() async {
    if (selectedSize == "") {
      showError("Lütfen bir beden seçin");
      return;
    }

    try {
      var address = Uri.parse("${ApiConfig.baseUrl}/products/save/${widget.userId}");
      var response = await http.post(
        address,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "url": searchedUrl,
          "price": double.tryParse(cleanPrice) ?? 0.0,
          "imageUrl": image,
          "targetSize": selectedSize,
          "inStockNotified": isSelectedSizeInStock
        }),
      );

      if (response.statusCode == 200) {
        showTopNotification("Ürün dolabına eklendi!", Colors.green.shade600);
      } else {
        showError("Hata: ${response.body}");
      }
    } catch (e) {
      showError("Bağlantı hatası");
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
                MaterialPageRoute(builder: (context) => ClosetScreen(userId: widget.userId)),
              );
            },
          ),
          // --- YENİ EKLENEN ÇIKIŞ (LOGOUT) BUTONU ---
          IconButton(
            icon: Icon(Icons.logout, color: Colors.redAccent), // Kırmızı şık bir çıkış ikonu
            onPressed: () {
              // pushAndRemoveUntil: Kullanıcıyı AuthScreen'e atar ve arkadaki tüm sayfa geçmişini yok eder!
              // Böylece Android'de fiziksel 'Geri' tuşuna bassa bile hesabın içine geri dönemez.
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => AuthScreen()),
                (Route<dynamic> route) => false, // Tüm geçmişi silme komutu
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
                  bool inStock = size.contains("Stokta") || size.contains("In Stock") || size.contains("Az Stok");
                  String cleanSize = size.replaceAll("(Stokta)", "").replaceAll("(Tükendi)", "").replaceAll("In Stock", "").replaceAll("Out of Stock", "").trim();
                  return ChoiceChip(
                    label: Text(cleanSize, style: TextStyle(color: Colors.black)),
                    selected: selectedSize == cleanSize,
                    onSelected: (selected) {
                      setState(() {
                        selectedSize = selected ? cleanSize : "";
                        isSelectedSizeInStock = selected ? inStock : false;
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

// --- DOLABIM EKRANI ---
class ClosetScreen extends StatefulWidget {
  final int userId; 
  ClosetScreen({required this.userId});

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
      var address = Uri.parse("${ApiConfig.baseUrl}/products/list/${widget.userId}");
      var response = await http.get(address);
      if (response.statusCode == 200) {
        setState(() {
          items = jsonDecode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      } else {
        setState(() { isLoading = false; });
      }
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

 void showTopNotification(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message, style: TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150, 
          left: 20, 
          right: 20
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void deleteItem(String url, String size) async {
    try {
      String encodedUrl = Uri.encodeComponent(url);
      String encodedSize = Uri.encodeComponent(size);
      
      var address = Uri.parse("${ApiConfig.baseUrl}/products/delete/${widget.userId}?url=$encodedUrl&size=$encodedSize");
      var response = await http.delete(address);
      if (response.statusCode == 200) {
        fetchCloset(); 
        // SİLİNCE EKRANIN ÜSTÜNDEN KIRMIZI BİLDİRİM DÜŞECEK
        showTopNotification("Ürün dolabından silindi!", Colors.red.shade600);
      }
    } catch (e) {}
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
          : items.isEmpty 
              ? Center(child: Text("Dolabın şu an boş", style: TextStyle(color: Colors.white54)))
              : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                var item = items[index];
                return Card(
                  color: Colors.grey[900],
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: item["imageUrl"] != null && item["imageUrl"] != "Yok"
                        ? Image.network(item["imageUrl"], width: 50, height: 50, fit: BoxFit.cover)
                        : Icon(Icons.image, color: Colors.white),
                    title: Text(item["name"] ?? "", style: TextStyle(color: Colors.white)),
                    subtitle: Text("${item["price"]} TL - Size: ${item["targetSize"] ?? ""}", style: TextStyle(color: Colors.green)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red.shade300),
                      onPressed: () => deleteItem(item["url"] ?? "", item["targetSize"] ?? ""
                    ),
                  ),
                )
                );
              },
            ),
    );
  }
}

// --- BİLDİRİMLER EKRANI ---
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
      var address = Uri.parse("${ApiConfig.baseUrl}/products/notifications");
      var response = await http.get(address);
      if (response.statusCode == 200) {
        setState(() {
          serverNotifications = jsonDecode(utf8.decode(response.bodyBytes));
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() { isLoading = false; });
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