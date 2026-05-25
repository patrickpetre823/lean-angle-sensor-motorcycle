// ============================================================
//  Moto Lean Angle Sensor – Erster Test
//  Hardware : Arduino Nano 33 BLE + BNO085
//  Protokoll: I2C (A4=SDA, A5=SCL)
// ============================================================

#include <Wire.h>
#include <Adafruit_BNO08x.h>

#define BNO08X_RESET -1   // RST nicht verkabelt? -1 lassen
                           // Wenn D3 an RST: #define BNO08X_RESET 3


float qr = 1.0, qi = 0.0, qj = 0.0, qk = 0.0;

Adafruit_BNO08x bno08x(BNO08X_RESET);
sh2_SensorValue_t sensorValue;

// ----------------------------------------------------------
void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);   // warten bis Serial Monitor offen ist

  Serial.println("=== Moto Lean Angle Sensor ===");
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
  Serial.println("Sensor bereit. Starte Messung...");
  Serial.println("----------------------------------");
  Serial.println("----------------------------------");
}

// ----------------------------------------------------------
void loop() {
  if (!bno08x.getSensorEvent(&sensorValue)) return;

  // Rotation
  if (sensorValue.sensorId == SH2_ROTATION_VECTOR) {

    // Quaternion auslesen
    qr = sensorValue.un.rotationVector.real;
    qi = sensorValue.un.rotationVector.i;
    qj = sensorValue.un.rotationVector.j;
    qk = sensorValue.un.rotationVector.k;

    // Quaternion → Euler-Winkel (Grad)
    float roll  = atan2(2*(qr*qi + qj*qk), 1 - 2*(qi*qi + qj*qj)) * 180.0 / PI;
    float pitch = asin (2*(qr*qj - qk*qi))                          * 180.0 / PI;
    float yaw   = atan2(2*(qr*qk + qi*qj), 1 - 2*(qj*qj + qk*qk)) * 180.0 / PI;

    // Ausgabe
    Serial.print("Roll: ");
    Serial.print(roll, 1);
    Serial.print("°  |  Pitch: ");
    Serial.print(pitch, 1);
    Serial.print("°  |  Yaw: ");
    Serial.print(yaw, 1);
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
  }
}
