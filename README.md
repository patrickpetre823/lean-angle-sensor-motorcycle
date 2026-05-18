# 🏍️ Motorcycle Lean Angle Sensor
 
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
 
### Milestone 1 — Sensor Works ✅ *(Hardware & Basic Firmware)*
 
**Goal:** Read lean angle data from the BNO085 and display it in the Serial Monitor.
 
- Set up the Arduino development environment
- Connect the BNO085 to the Arduino Nano 33 BLE via I2C
- Read raw orientation data (roll, pitch, yaw) from the sensor
- Verify that the lean angle reading is stable and correct
- Document the wiring and the basic firmware
**Done when:** The Serial Monitor shows a stable, correct lean angle when the sensor is tilted by hand.
 
---
 
### Milestone 2 — Data via Bluetooth 📡 *(BLE Communication)*
 
**Goal:** Send the lean angle data from the Arduino to a smartphone in real time.
 
- Implement a BLE GATT service on the Arduino
- Define a characteristic for the lean angle value
- Connect a smartphone to the Arduino using a generic BLE app (e.g. nRF Connect)
- Verify that the data arrives correctly on the phone
**Done when:** A smartphone can connect to the Arduino and see the live lean angle value updating in real time.
 
---
 
### Milestone 3 — Data Logging 💾 *(Recording & Storage)*
 
**Goal:** Record the lean angle data during a ride and save it for later analysis.
 
- Decide on a logging strategy: log on the phone, on an SD card, or in the Arduino's memory
- Implement timestamped data recording
- Define the data format (e.g. CSV or JSON)
- Test data recording during a short test ride
**Done when:** After a test ride, a complete log file with timestamps and lean angles is available.
 
---
 
### Milestone 4 — Ride Analysis 📊 *(Visualization & App)*
 
**Goal:** Make the recorded data easy to understand and useful.
 
- Build a simple interface (smartphone app or web app) to display the recorded data
- Show key statistics: max lean angle left, max lean angle right, ride duration, etc.
- Optionally: show a time-based chart of the lean angle over the ride
- Test with real ride data
**Done when:** A rider can finish a ride and immediately see their lean angle statistics on their phone.
 
---
 
 
### Required Libraries (Arduino)
 
- `Arduino_BHY2` or `Adafruit BNO08x` — for reading data from the BNO085
- `ArduinoBLE` — for Bluetooth Low Energy communication
---
 
## Contributing
 
This is a personal project, but feedback and ideas are always welcome. Feel free to open an issue if you have a suggestion or find a bug.
 
---
 
## License
 
MIT License — feel free to use, modify, and share.
