import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(ASFManagerApp());

class ASFManagerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASF Manager',
      theme: ThemeData(primarySwatch: Colors.blue, brightness: Brightness.dark),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String asfUrl = 'http://45.144.66.91:1242';
  String asfPassword = 'yourpassword';
  String botName = 'MyBot';
  String status = 'Нажми "Статус" для проверки';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      asfUrl = prefs.getString('asfUrl') ?? 'http://45.144.66.91:1242';
      asfPassword = prefs.getString('asfPassword') ?? 'yourpassword';
      botName = prefs.getString('botName') ?? 'MyBot';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('asfUrl', asfUrl);
    await prefs.setString('asfPassword', asfPassword);
    await prefs.setString('botName', botName);
  }

  Future<Map<String, dynamic>> _asfRequest(String method, String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final url = Uri.parse('$asfUrl$endpoint');
      final headers = {
        'Authentication': asfPassword,
        'Content-Type': 'application/json',
      };

      http.Response response;
      if (method == 'GET') {
        response = await http.get(url, headers: headers).timeout(Duration(seconds: 10));
      } else if (method == 'POST') {
        response = await http.post(url, headers: headers, body: jsonEncode(body)).timeout(Duration(seconds: 10));
      } else if (method == 'DELETE') {
        response = await http.delete(url, headers: headers).timeout(Duration(seconds: 10));
      } else {
        throw Exception('Unsupported method');
      }

      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<void> _playGame(int appId, String gameName) async {
    setState(() {
      isLoading = true;
      status = 'Запускаю $gameName...';
    });

    final result = await _asfRequest('POST', '/Api/Bot/$botName/GamesToFarm', body: {'GameIDs': [appId]});

    setState(() {
      isLoading = false;
      if (result.containsKey('error')) {
        status = '❌ Ошибка: ${result['error']}';
      } else {
        status = '✅ Фармим: $gameName';
      }
    });
  }

  Future<void> _stopFarming() async {
    setState(() {
      isLoading = true;
      status = 'Останавливаю...';
    });

    final result = await _asfRequest('DELETE', '/Api/Bot/$botName/GamesToFarm');

    setState(() {
      isLoading = false;
      if (result.containsKey('error')) {
        status = '❌ Ошибка: ${result['error']}';
      } else {
        status = '⏹ Фарминг остановлен';
      }
    });
  }

  Future<void> _checkStatus() async {
    setState(() {
      isLoading = true;
      status = 'Проверяю...';
    });

    final result = await _asfRequest('GET', '/Api/Bot/$botName');

    setState(() {
      isLoading = false;
      if (result.containsKey('error')) {
        status = '❌ Ошибка: ${result['error']}';
      } else {
        final bots = result['Result'] as Map<String, dynamic>?;
        if (bots != null && bots.isNotEmpty) {
          final botInfo = bots.values.first;
          final isOnline = botInfo['IsConnectedAndLoggedOn'] ?? false;
          final farming = botInfo['CurrentGamesFarming'] as List? ?? [];
          final farmingText = farming.isEmpty ? 'Ничего' : farming.join(', ');
          status = '📊 Статус: ${isOnline ? "🟢 Онлайн" : "🔴 Оффлайн"}\n🎮 Фармит: $farmingText';
        } else {
          status = '❓ Бот не найден';
        }
      }
    });
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) {
        String tempUrl = asfUrl;
        String tempPassword = asfPassword;
        String tempBotName = botName;

        return AlertDialog(
          title: Text('Настройки'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'ASF URL'),
                controller: TextEditingController(text: tempUrl),
                onChanged: (val) => tempUrl = val,
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Пароль'),
                controller: TextEditingController(text: tempPassword),
                onChanged: (val) => tempPassword = val,
                obscureText: true,
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Имя бота'),
                controller: TextEditingController(text: tempBotName),
                onChanged: (val) => tempBotName = val,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  asfUrl = tempUrl;
                  asfPassword = tempPassword;
                  botName = tempBotName;
                });
                _saveSettings();
                Navigator.pop(context);
              },
              child: Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ASF Manager'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),
            if (isLoading) CircularProgressIndicator(),
            if (!isLoading) ...[
              ElevatedButton.icon(
                onPressed: () => _playGame(730, 'CS2'),
                icon: Icon(Icons.videogame_asset),
                label: Text('Играть CS2'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _playGame(570, 'Dota 2'),
                icon: Icon(Icons.videogame_asset),
                label: Text('Играть Dota 2'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _stopFarming,
                icon: Icon(Icons.stop),
                label: Text('Стоп'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.red,
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _checkStatus,
                icon: Icon(Icons.info),
                label: Text('Статус'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
