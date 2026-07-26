import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';
import 'database_helper.dart';

void main() {
  runApp(const MotoLeanApp());
}

class MotoLeanApp extends StatelessWidget {
  const MotoLeanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moto Lean Sensor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const HomePage(),   // NEU: Einstieg ist jetzt HomePage
    );
  }
}

// ============================================================
//  HomePage — Einstiegsseite mit zwei Optionen
// ============================================================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Moto Lean Sensor')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            const Icon(Icons.two_wheeler, size: 72, color: Colors.white30),
            const SizedBox(height: 40),

            // Neuer Messlauf → öffnet den BLE-Scan
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.bluetooth_searching),
                label: const Text('Neuer Messlauf'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ScanPage()),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Vergangene Läufe → öffnet die History
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.history),
                label: const Text('Vergangene Läufe'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryPage()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  ScanPage — BLE-Scan, zeigt alle MotoLean-Geräte
// ============================================================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _isScanning = false;

  void _startScan() async {
    setState(() => _isScanning = true);
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sensor suchen')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                child: Text(_isScanning ? 'Suche läuft...' : 'Suche starten'),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<ScanResult>>(
                stream: FlutterBluePlus.scanResults,
                initialData: const [],
                builder: (context, snapshot) {
                  // Nur MotoLean-Geräte anzeigen
                  final results = snapshot.data!
                      .where((r) => r.device.platformName.contains('MotoLean'))
                      .toList();

                  if (results.isEmpty) {
                    return const Center(
                      child: Text(
                        'Kein Sensor gefunden.\nSensor einschalten und Suche starten.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return ListTile(
                        title: Text(result.device.platformName),
                        subtitle: Text('Signal: ${result.rssi} dBm'),
                        trailing: const Icon(Icons.bluetooth),
                        onTap: () {
                          FlutterBluePlus.stopScan();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SensorPage(device: result.device),
                            ),
                          );
                        },
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
//  SensorPage — Live-Anzeige + Aufnahme starten/stoppen
// ============================================================
class SensorPage extends StatefulWidget {
  final BluetoothDevice device;
  const SensorPage({super.key, required this.device});

  @override
  State<SensorPage> createState() => _SensorPageState();
}

class _SensorPageState extends State<SensorPage> {
  static const String serviceUuid = '19b10000-e8f2-537e-4f6c-d104768a1214';
  static const String orientUuid  = '19b10001-e8f2-537e-4f6c-d104768a1214';
  static const String accelUuid   = '19b10002-e8f2-537e-4f6c-d104768a1214';

  double _roll = 0, _pitch = 0, _yaw = 0;
  double _ax = 0, _ay = 0, _az = 0;
  bool _connected = false;

  // Aufnahme
  bool _recording = false;
  int? _currentRunId;
  final _db = DatabaseHelper();

  // Stream-Subscriptions — müssen in dispose() gestoppt werden
  StreamSubscription? _orientSub;
  StreamSubscription? _accelSub;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() async {
    await widget.device.connect();
    if (!mounted) return;
    setState(() => _connected = true);

    List<BluetoothService> services = await widget.device.discoverServices();

    for (BluetoothService service in services) {
      if (service.uuid.toString() == serviceUuid) {
        for (BluetoothCharacteristic c in service.characteristics) {
          final uuid = c.uuid.toString();

          if (uuid == orientUuid) {
            await c.setNotifyValue(true);
            _orientSub = c.onValueReceived.listen((value) {
              if (!mounted) return;
              final parts = utf8.decode(value).split(',');
              if (parts.length == 3) {
                setState(() {
                  _roll  = double.tryParse(parts[0]) ?? 0;
                  _pitch = double.tryParse(parts[1]) ?? 0;
                  _yaw   = double.tryParse(parts[2]) ?? 0;
                });
                // In DB schreiben wenn Aufnahme läuft
                if (_recording && _currentRunId != null) {
                  _db.insertReading(
                    runId: _currentRunId!,
                    roll: _roll, pitch: _pitch, yaw: _yaw,
                    ax: _ax, ay: _ay, az: _az,
                  );
                }
              }
            });
          }

          if (uuid == accelUuid) {
            await c.setNotifyValue(true);
            _accelSub = c.onValueReceived.listen((value) {
              if (!mounted) return;
              final parts = utf8.decode(value).split(',');
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

  void _toggleRecording() async {
    if (_recording) {
      setState(() {
        _recording = false;
        _currentRunId = null;
      });
    } else {
      final runId = await _db.createRun();
      setState(() {
        _recording = true;
        _currentRunId = runId;
      });
    }
  }

  @override
  void dispose() {
    _orientSub?.cancel();
    _accelSub?.cancel();
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live-Daten'),
        actions: [
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

            // Schräglage — Hauptwert
            const Text('Schräglage', style: TextStyle(color: Colors.white54, fontSize: 16)),
            Text(
              '${_roll.toStringAsFixed(1)}°',
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _valueCard('Pitch', _pitch),
                _valueCard('Yaw', _yaw),
              ],
            ),

            const SizedBox(height: 24),

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

            const SizedBox(height: 32),

            // Aufnahme-Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: Icon(_recording ? Icons.stop : Icons.fiber_manual_record),
                label: Text(_recording ? 'Aufnahme stoppen' : 'Aufnahme starten'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _recording ? Colors.red : Colors.green,
                ),
                onPressed: _toggleRecording,
              ),
            ),

            // Aufnahme-Indikator
            if (_recording) ...[
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.circle, color: Colors.red, size: 10),
                  SizedBox(width: 6),
                  Text('Aufnahme läuft', style: TextStyle(color: Colors.red)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

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

// ============================================================
//  HistoryPage — Liste aller vergangenen Messläufe
// ============================================================
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _runs = [];

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  // Alle Läufe aus der DB laden
  void _loadRuns() async {
    final runs = await _db.getRuns();
    // Für jeden Lauf die Anzahl der Messungen nachladen
    final enriched = await Future.wait(
      runs.map((run) async {
        final count = await _db.getReadingCount(run['id']);
        return {...run, 'count': count};
      }),
    );
    if (!mounted) return;
    setState(() => _runs = enriched);
  }

  // Datum aus ISO-String lesbar formatieren
  String _formatDate(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}  '
           '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vergangene Läufe')),
      body: _runs.isEmpty
          ? const Center(
              child: Text(
                'Noch keine Läufe aufgezeichnet.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _runs.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final run = _runs[index];
                return ListTile(
                  leading: const Icon(Icons.two_wheeler),
                  title: Text(_formatDate(run['started_at'])),
                  subtitle: Text('${run['count']} Messungen'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetailPage(
                        runId: run['id'],
                        title: _formatDate(run['started_at']),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
//  DetailPage — Platzhalter, Diagramm kommt später
// ============================================================
class DetailPage extends StatefulWidget {
  final int runId;
  final String title;
  const DetailPage({super.key, required this.runId, required this.title});

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  final _db = DatabaseHelper();
  List<Map<String, dynamic>> _readings = [];

  @override
  void initState() {
    super.initState();
    _loadReadings();
  }

  void _loadReadings() async {
    final readings = await _db.getReadingsForRun(widget.runId);
    if (!mounted) return;
    setState(() => _readings = readings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _readings.isEmpty
          ? const Center(child: Text('Keine Messungen in diesem Lauf.'))
          : Column(
              children: [
                // Info-Leiste oben
                Container(
                  width: double.infinity,
                  color: Colors.white10,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  child: Text(
                    '${_readings.length} Messungen  ·  Diagramm folgt in Milestone 3',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                // Vorerst Rohdaten als Liste
                Expanded(
                  child: ListView.builder(
                    itemCount: _readings.length,
                    itemBuilder: (context, index) {
                      final r = _readings[index];
                      // Zeitstempel relativ zum ersten Eintrag anzeigen
                      final ms = r['timestamp_ms'] - _readings[0]['timestamp_ms'];
                      final sec = (ms / 1000).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: Text(
                                '+${sec}s',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                            ),
                            Text(
                              'Roll: ${(r['roll'] as double).toStringAsFixed(1)}°  '
                              'Pitch: ${(r['pitch'] as double).toStringAsFixed(1)}°  '
                              'Yaw: ${(r['yaw'] as double).toStringAsFixed(1)}°',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}