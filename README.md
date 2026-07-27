# Motorcycle Lean Angle Sensor
 
A DIY project to measure and record the lean angle of a motorcycle in real time — and send the data to a smartphone for post-ride analysis.
 
> *"How far did I actually lean in that corner?"* — This project answers exactly that question.
 
---
 
## 📋 Table of Contents
 
- [Project Goal](#project-goal)
- [Hardware](#hardware)
- [Project Roadmap](#project-roadmap)
- [Getting Started](#getting-started)
- [Contributing](#contributing)
- [License](#license)
---
 
## Project Goal
 
The goal of this project is to build a small, self-contained sensor unit that mounts on a motorcycle and continuously measures the lean angle (roll angle) during a ride. The data is transmitted wirelessly to a smartphone via Bluetooth Low Energy (BLE). After the ride, the rider can open an app (or a simple web interface) and review the recorded data — for example:
 
- What was the maximum lean angle to the left?
- What was the maximum lean angle to the right?
- How did the lean angle change over time throughout the ride?
The project is intentionally kept simple and modular, so it is easy to understand, extend, and adapt.
 
---
 
## Hardware
 
### Components
 
| Component | Description |
|---|---|
| **Arduino Nano 33 BLE** | The main microcontroller. Has built-in Bluetooth Low Energy (BLE), which makes it perfect for sending data to a smartphone without any extra module. |
| **BNO085** | A high-quality IMU (Inertial Measurement Unit) from CEVA/Hillcrest. It contains an accelerometer, gyroscope, and magnetometer — and most importantly, it has an internal sensor fusion processor that directly outputs stable rotation data (quaternions or Euler angles). This makes it much more reliable than a raw accelerometer alone. |
 
### Why These Components?
 
The **BNO085** was chosen because it handles all the complex math internally. Instead of dealing with gyroscope drift or manual sensor fusion, the sensor outputs a ready-to-use orientation — including the roll angle (lean angle) directly. This is exactly what we need for a motorcycle application where vibrations and dynamic movements would otherwise cause problems.
 
The **Arduino Nano 33 BLE** was chosen because it is small, easy to program, runs on 3.3V (compatible with the BNO085), and has BLE built in. No extra Bluetooth module needed.
 
### Wiring
 
*To be documented once the first prototype is assembled.*
 
### Power Supply
 
*To be defined. Options: small LiPo battery, USB power bank, or connection to the motorcycle's 12V system via a step-down converter.*
 
---
 
## Project Roadmap
 
The project is divided into four milestones. Each milestone has a clear deliverable and builds on the previous one.
 
---
 
### Milestone 1 — Sensor Works *(Hardware & Basic Firmware)*
 
**Goal:** Read lean angle data from the BNO085 and display it in the Serial Monitor.
 
- Set up the Arduino development environment
- Connect the BNO085 to the Arduino Nano 33 BLE via I2C
- Read raw orientation data (roll, pitch, yaw) from the sensor
- Verify that the lean angle reading is stable and correct
- Document the wiring and the basic firmware
**Done when:** The Serial Monitor shows a stable, correct lean angle when the sensor is tilted by hand.
 
---
 
![alt text](https://github.com/adam-p/markdown-here/raw/master/src/common/images/icon48.png "Logo Title Text 1")
![alt text](https://github.com/patrickpetre823/lean-angle-sensor-motorcycle/tree/main/docs/sensorboard.jpeg "Sensor Board")
---

### Milestone 2 — Flutter App & BLE *(Mobile App & Bluetooth)*

**Goal:** Build a Flutter Android app that connects to the Arduino via BLE and displays live sensor data.

- Implement a BLE GATT service on the Arduino (orientation + acceleration characteristics)
- Set up a Flutter project and establish a BLE connection to the Arduino
- Display live lean angle, pitch, yaw, and acceleration values in the app
- Verify stable real-time data transfer

**Done when:** The Flutter app connects to the Arduino and shows all sensor values updating live.

---

### Milestone 3 — Data Logging 💾 *(Recording & Storage)*

**Goal:** Record all sensor data during a ride and store it locally on the phone for later analysis.

- Implement timestamped data logging in the Flutter app (SQLite)
- Define the data format (timestamp, roll, pitch, yaw, ax, ay, az)
- Build a ride history view: list of past sessions, each openable for detail
- Add CSV export for further analysis in external tools
- Test recording during a short test ride

**Done when:** After a ride, a complete session log is stored on the phone and exportable as CSV.

---

### Milestone 4 — GPS Overlay 🗺️ *(Ride Analysis)*

**Goal:** Combine lean angle data with GPS position to visualize cornering behavior on a map.

- Capture GPS coordinates via the phone's location API during a ride
- Synchronize GPS and sensor data by timestamp
- Display the ride track on a map with lean angle encoded as color (e.g. green = upright, red = deep lean)
- Allow filtering and scrubbing through the session in the detail view

**Done when:** A recorded ride can be replayed on a map with lean angle overlaid on the route.

---

### Milestone 5 — Field Test & Mounting 🏍️ *(Real-World Validation)*

**Goal:** Mount the sensor on the motorcycle and validate data quality during a real ride.

- Design and 3D-print a weatherproof, vibration-damped enclosure
- Mount the sensor on the motorcycle and run the startup calibration
- Validate lean angle readings against known reference corners
- Assess data quality under real-world vibration and temperature conditions
- Document mounting location, orientation, and any required axis remapping
 
 
### Required Libraries (Arduino)
 
- `Arduino_BHY2` or `Adafruit BNO08x` — for reading data from the BNO085
- `ArduinoBLE` — for Bluetooth Low Energy communication
---
 
## Contributing
 
This is a personal project, but feedback and ideas are always welcome. Feel free to open an issue if you have a suggestion or find a bug.
 
---
 
## License
 
MIT License — feel free to use, modify, and share.
