// ============================================================
//  Moto Lean Angle Sensor – Erster Test
//  Hardware : Arduino Nano 33 BLE + BNO085
//  Protokoll: I2C (A4=SDA, A5=SCL)
// ============================================================

#include <Wire.h>
#include <Adafruit_BNO08x.h>
#include <ArduinoBLE.h>

#define BNO08X_RESET -1   // RST nicht verkabelt? -1 lassen
                           // Wenn D3 an RST: #define BNO08X_RESET 3

Adafruit_BNO08x bno08x(BNO08X_RESET);
sh2_SensorValue_t sensorValue;

BLEService sensorService("19b10000-e8f2-537e-4f6c-d104768a1214");

BLECharacteristic orientCharacteristic(
  "19b10001-e8f2-537e-4f6c-d104768a1214",
  BLENotify,    // Handy bekommt automatisch jedes Update
  20            // max. Paketgröße in Bytes
);

BLECharacteristic accelCharacteristic(
  "19b10002-e8f2-537e-4f6c-d104768a1214",
  BLENotify,
  20
);

float qr = 1.0, qi = 0.0, qj = 0.0, qk = 0.0;

// Referenz-Quaternion für Kalibrierung (Einbaulage)
// Startwert = Einheitsquaternion = "keine Drehung" = unkalibriert
float ref_qr = 1.0, ref_qi = 0.0, ref_qj = 0.0, ref_qk = 0.0;

bool calibrated = false;

// ----------------------------------------------------------
// Quaternion-Multiplikation: result = a ⊗ b
// Wird gebraucht um q_relativ = q_ref⁻¹ ⊗ q_aktuell zu berechnen
// ----------------------------------------------------------
void quatMultiply(float ar, float ai, float aj, float ak,
                  float br, float bi, float bj, float bk,
                  float &rr, float &ri, float &rj, float &rk) {
  rr = ar*br - ai*bi - aj*bj - ak*bk;
  ri = ar*bi + ai*br + aj*bk - ak*bj;
  rj = ar*bj - ai*bk + aj*br + ak*bi;
  rk = ar*bk + ai*bj - aj*bi + ak*br;
}

// ----------------------------------------------------------
// Quaternion → Euler-Winkel in Grad
// ----------------------------------------------------------
void quatToEuler(float qr, float qi, float qj, float qk,
                 float &roll, float &pitch, float &yaw) {
  roll  = atan2(2*(qr*qi + qj*qk), 1 - 2*(qi*qi + qj*qj)) * 180.0 / PI;
  pitch = asin (2*(qr*qj - qk*qi))                          * 180.0 / PI;
  yaw   = atan2(2*(qr*qk + qi*qj), 1 - 2*(qj*qj + qk*qk)) * 180.0 / PI;
}

// ----------------------------------------------------------
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);   // warten bis Serial Monitor offen ist

  Serial.println("=== Moto Lean Angle Sensor ===");
  Serial.println("Befehle: 'C' = Kalibrieren  |  'R' = Reset");
  Serial.println("Initialisiere BNO085...");

  if (!bno08x.begin_I2C()) {
    Serial.println("FEHLER: BNO085 nicht gefunden!");
    Serial.println("Verkabelung pruefen: 3.3V, GND, SDA(A4), SCL(A5)");
    while (1) delay(10);
  }

  Serial.println("BNO085 gefunden!");

  // Rotation Vector aktivieren (gibt stabile Quaternionen aus)
  if (!bno08x.enableReport(SH2_ROTATION_VECTOR, 10000)) { // 10ms = 100Hz
    Serial.println("FEHLER: Rotation Vector Report konnte nicht aktiviert werden.");
    while (1) delay(10);
  }
  if (!bno08x.enableReport(SH2_LINEAR_ACCELERATION, 10000)) {
    Serial.println("FEHLER: Linear Acceleration Report konnte nicht aktiviert werden.");
    while (1) delay(10);
  }


  // ===================== NEU: BLE Setup =====================
  // Startet den Bluetooth-Stack auf dem Arduino
  if (!BLE.begin()) {
    Serial.println("FEHLER: BLE konnte nicht gestartet werden.");
    while (1) delay(10);
  }

  // Name unter dem der Arduino im Scan der App erscheint
  BLE.setLocalName("MotoLeanSensor");
  BLE.setAdvertisedService(sensorService);

  // Beide Charakteristiken dem Service zuordnen
  sensorService.addCharacteristic(orientCharacteristic);
  sensorService.addCharacteristic(accelCharacteristic);
  BLE.addService(sensorService);

  // Arduino ab jetzt für Scans sichtbar machen
  BLE.advertise();

  Serial.println("BLE aktiv. Warte auf Verbindung vom Handy...");
  // ================== ENDE NEU: BLE Setup ====================


  // Warten bis Sensor stabile Werte liefert, dann automatisch kalibrieren
  Serial.println("Kalibrierung in 10 Sekunden — Motorrad gerade hinstellen...");

  for (int i = 10; i > 0; i--) {
    Serial.print(i);
    Serial.println("...");
    delay(1000);
  }

  // Einen frischen Messwert holen und als Nullpunkt speichern
  while (!bno08x.getSensorEvent(&sensorValue) ||
        sensorValue.sensorId != SH2_ROTATION_VECTOR) {
    delay(10);
  }
  ref_qr = sensorValue.un.rotationVector.real;
  ref_qi = sensorValue.un.rotationVector.i;
  ref_qj = sensorValue.un.rotationVector.j;
  ref_qk = sensorValue.un.rotationVector.k;
  calibrated = true;

  Serial.println(">>> Nullpunkt gesetzt. Messung laeuft.");
  }

// ----------------------------------------------------------
void loop() {
  
  // ============ NEU: prüfen ob ein Handy verbunden ist ============
  // Nicht zwingend nötig zum Senden, aber so weiß der Arduino
  // ob gerade eine BLE-Verbindung aktiv ist (für späteres Debugging nützlich)
  BLEDevice central = BLE.central();
  // ========================== ENDE NEU =============================

  if (!bno08x.getSensorEvent(&sensorValue)) return;

  // Rotation
  if (sensorValue.sensorId == SH2_ROTATION_VECTOR) {

    // Quaternion auslesen
    qr = sensorValue.un.rotationVector.real;
    qi = sensorValue.un.rotationVector.i;
    qj = sensorValue.un.rotationVector.j;
    qk = sensorValue.un.rotationVector.k;

    // Quaternion → Euler-Winkel (Grad)
    //float roll  = atan2(2*(qr*qi + qj*qk), 1 - 2*(qi*qi + qj*qj)) * 180.0 / PI;
    //float pitch = asin (2*(qr*qj - qk*qi))                          * 180.0 / PI;
    //float yaw   = atan2(2*(qr*qk + qi*qj), 1 - 2*(qj*qj + qk*qk)) * 180.0 / PI;

    // Wenn kalibriert, erst relatives Quaternion berechnen
    float rr, ri, rj, rk;
    if (calibrated) {
      // q_relativ = q_ref⁻¹ ⊗ q_aktuell
      // Das Inverse = Konjugiertes: i/j/k-Anteile des Referenz-Quaternions negieren
      rr = ref_qr*qr + ref_qi*qi + ref_qj*qj + ref_qk*qk;
      ri = ref_qr*qi - ref_qi*qr - ref_qj*qk + ref_qk*qj;
      rj = ref_qr*qj + ref_qi*qk - ref_qj*qr - ref_qk*qi;
      rk = ref_qr*qk - ref_qi*qj + ref_qj*qi - ref_qk*qr;
    } else {
      // Nicht kalibriert: einfach den rohen Quaternion weiterverwenden
      rr = qr; ri = qi; rj = qj; rk = qk;
    }

    // Euler-Winkel aus rr/ri/rj/rk — egal ob kalibriert oder nicht
    float roll  = atan2(2*(rr*ri + rj*rk), 1 - 2*(ri*ri + rj*rj)) * 180.0 / PI;
    float pitch = asin (2*(rr*rj - rk*ri))                          * 180.0 / PI;
    float yaw   = atan2(2*(rr*rk + ri*rj), 1 - 2*(rj*rj + rk*rk)) * 180.0 / PI;

    // Ausgabe
    Serial.print(calibrated ? "" : "[!] ");  // Nur warnen wenn NICHT kalibriert
    Serial.print("Roll: ");
    Serial.print(roll, 1);
    Serial.print("°  |  Pitch: ");
    Serial.print(pitch, 1);
    Serial.print("°  |  Yaw: ");
    Serial.print(yaw, 1);
    
    // ===================== NEU: per BLE senden =====================
    // String im Format "roll,pitch,yaw" bauen, z.B. "32.4,-1.2,143.8"
    // Das ist exakt das Format, das die Flutter-App mit .split(',') erwartet
    char orientBuf[20];
    snprintf(orientBuf, sizeof(orientBuf), "%.1f,%.1f,%.1f", roll, pitch, yaw);
    orientCharacteristic.writeValue(orientBuf);
    // ========================== ENDE NEU ============================
  
  }

  // Accelaration
  if (sensorValue.sensorId == SH2_LINEAR_ACCELERATION) {
    float ax = sensorValue.un.linearAcceleration.x;
    float ay = sensorValue.un.linearAcceleration.y;
    float az = sensorValue.un.linearAcceleration.z;

    // In Weltkoordinaten rotieren (qr/qi/qj/qk vom letzten Rotation-Vector-Event)
    float ax_welt = (1 - 2*(qj*qj + qk*qk))*ax + 2*(qi*qj - qr*qk)*ay + 2*(qi*qk + qr*qj)*az;
    float ay_welt = 2*(qi*qj + qr*qk)*ax       + (1 - 2*(qi*qi + qk*qk))*ay + 2*(qj*qk - qr*qi)*az;
    float az_welt = 2*(qi*qk - qr*qj)*ax       + 2*(qj*qk + qr*qi)*ay   + (1 - 2*(qi*qi + qj*qj))*az;

    Serial.print("Accel Sensor:  X="); Serial.print(ax, 2);
    Serial.print("  Y="); Serial.print(ay, 2);
    Serial.print("  Z="); Serial.println(az, 2);

    Serial.print("Accel Welt:    X="); Serial.print(ax_welt, 2);
    Serial.print("  Y="); Serial.print(ay_welt, 2);
    Serial.print("  Z="); Serial.println(az_welt, 2);

    // ===================== NEU: per BLE senden =====================
    // String im Format "x,y,z", z.B. "0.34,-0.12,9.81"
    char accelBuf[20];
    snprintf(accelBuf, sizeof(accelBuf), "%.2f,%.2f,%.2f", ax_welt, ay_welt, az_welt);
    accelCharacteristic.writeValue(accelBuf);
    // ========================== ENDE NEU ============================
  }
}
