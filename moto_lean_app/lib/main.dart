import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';

// ============================================================
//  Einstiegspunkt der App
//  runApp() startet die Flutter-App mit unserem Widget
// ============================================================
void main() {
  runApp(const MotoLeanApp());
}

// ============================================================
//  MotoLeanApp — Root-Widget
//  MaterialApp gibt uns das Android-Look-and-Feel
// ============================================================
class MotoLeanApp extends StatelessWidget {
  const MotoLeanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moto Lean Sensor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),        // dunkles Theme — gut lesbar am Motorrad
      home: const ScanPage(),
    );
  }
}

// ============================================================
//  ScanPage — Startseite mit BLE-Scan
//  StatefulWidget weil sich der Zustand ändert (scanning, gefunden, etc.)
// ============================================================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _isScanning = false;

  // Startet den BLE-Scan
  // Wir suchen 5 Sekunden lang nach Geräten in der Nähe
  void _startScan() async {
    setState(() => _isScanning = true);

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moto Lean Sensor')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            // Scan-Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                child: Text(_isScanning ? 'Suche läuft...' : 'Sensor suchen'),
              ),
            ),

            const SizedBox(height: 24),

            // Gefundene Geräte live anzeigen
            // StreamBuilder hört auf den Scan-Stream und baut die Liste neu
            // wenn ein neues Gerät gefunden wird
            Expanded(
              child: StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                initialData: const [],
                builder: (context, snapshot) {
                  final results = snapshot.data!;

                  if (results.isEmpty) {
                    return const Center(
                      child: Text(
                        'Keine Geräte gefunden.\nSensor einschalten und "Sensor suchen" tippen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  // Für jedes gefundene BLE-Gerät eine Zeile anzeigen
                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      final name = result.device.platformName;
                      final rssi = result.rssi;  // Signalstärke in dBm

                      return ListTile(
                        title: Text(name.isEmpty ? '(kein Name)' : name),
                        subtitle: Text('Signal: $rssi dBm'),
                        trailing: const Icon(Icons.bluetooth),
                        // Nur "MotoLeanSensor" ist tippbar
                        onTap: name == 'MotoLeanSensor'
                            ? () {
                                FlutterBluePlus.stopScan();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SensorPage(
                                      device: result.device,
                                    ),
                                  ),
                                );
                              }
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  SensorPage — Live-Anzeige der Sensordaten
// ============================================================
class SensorPage extends StatefulWidget {
  final BluetoothDevice device;
  const SensorPage({super.key, required this.device});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  // UUIDs müssen exakt mit dem Arduino-Code übereinstimmen
  static const String serviceUuid       = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String orientUuid        = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String accelUuid         = '19b10002-e8f2-537e-4f6c-d104768a1214';

  // Aktuelle Messwerte
  double _roll = 0, _pitch = 0, _yaw = 0;
  double _ax = 0, _ay = 0, _az = 0;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  // Verbindung aufbauen und Charakteristiken abonnieren
  void _connect() async {
    await widget.device.connect();
    setState(() => _connected = true);

    // Alle Services des Geräts laden
    List<BluetoothService> services = await widget.device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString() == serviceUuid) {

        for (BluetoothCharacteristic c in service.characteristics) {
          final uuid = c.uuid.toString();

          // Orientierungs-Charakteristik abonnieren
          // Jedes Mal wenn Arduino neue Daten schickt, wird dieser Block ausgeführt
          if (uuid == orientUuid) {
            await c.setNotifyValue(true);
            c.lastValueStream.listen((value) {
              // Wert ist ein Byte-Array → in String umwandeln → aufteilen
              // Format vom Arduino: "32.4,-1.2,143.8"
              final str = utf8.decode(value);
              final parts = str.split(',');
              if (parts.length == 3) {
                setState(() {
                  _roll  = double.tryParse(parts[0]) ?? 0;
                  _pitch = double.tryParse(parts[1]) ?? 0;
                  _yaw   = double.tryParse(parts[2]) ?? 0;
                });
              }
            });
          }

          // Beschleunigungs-Charakteristik abonnieren
          if (uuid == accelUuid) {
            await c.setNotifyValue(true);
            c.lastValueStream.listen((value) {
              final str = utf8.decode(value);
              final parts = str.split(',');
              if (parts.length == 3) {
                setState(() {
                  _ax = double.tryParse(parts[0]) ?? 0;
                  _ay = double.tryParse(parts[1]) ?? 0;
                  _az = double.tryParse(parts[2]) ?? 0;
                });
              }
            });
          }
        }
      }
    }
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live-Daten'),
        actions: [
          // Verbindungsstatus-Anzeige oben rechts
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              Icons.circle,
              color: _connected ? Colors.greenAccent : Colors.red,
              size: 14,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // Roll — groß und zentriert (Hauptwert)
            const Text('Schräglage', style: TextStyle(color: Colors.white54, fontSize: 16)),
            Text(
              '${_roll.toStringAsFixed(1)}°',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 32),

            // Pitch und Yaw nebeneinander
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _valueCard('Pitch', _pitch),
                _valueCard('Yaw', _yaw),
              ],
            ),

            const SizedBox(height: 32),

            // Beschleunigung
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Beschleunigung (Welt)', style: TextStyle(color: Colors.white54)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _valueCard('X', _ax, unit: 'm/s²'),
                _valueCard('Y', _ay, unit: 'm/s²'),
                _valueCard('Z', _az, unit: 'm/s²'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Hilfsfunktion — kleines Werte-Widget
  Widget _valueCard(String label, double value, {String unit = '°'}) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}