# BLT - Bus Location Tracker Admin Portal

Welcome to the **BLT Admin Portal**, the centralized management console for the Bus Location Tracker system. Built with Flutter, this web-optimized application provides administrators with live tracking, fleet management, route coordination, and real-time reports.

The portal has been custom-refactored to offer a responsive, animated, and responsive web-focused user interface aligning with high-end administrative dashboard experiences.

---

## 📐 System Architecture Overview

The admin portal works as the master controller of the BLT system, interacting with Firebase services to manage mobile application roles and display real-time tracking data sent from hardware modules.

```txt
  +-----------------------------------+
  |       NEO-6M GPS Satellite        |
  +-----------------------------------+
                   │ (GPS Signals)
                   ▼
  +-----------------------------------+
  |   ESP8266 NodeMCU Module in Bus   |
  +-----------------------------------+
                   │ (WiFi Connection)
                   ▼
  +-----------------------------------+
  | Firebase Realtime Database (RTDB) | ◄───[Listen Live coordinates]
  +-----------------------------------+               │
                   ▲                                  │
                   │ (Sync User Profiles)             │
  +-----------------------------------+               │
  |   Cloud Firestore & Firebase Auth  |               │
  +-----------------------------------+               │
                   ▲                                  ▼
                   │                  +-------------------------------+
                   └──────────────────|    BLT Admin Web Portal       |
                                      +-------------------------------+
                                      |  • Live Fleet Map Preview     |
                                      |  • Routes & Driver Allocations|
                                      |  • Dynamic Management Grids   |
                                      |  • System & Delay Reports     |
                                      +-------------------------------+
```

---

## 🎨 Design System & Interactive Features

The portal implements a cohesive, high-fidelity design style built on Flutter's Material 3 components:

*   **Adaptive Layout Shell (`AdminDashboardScreen`)**: 
    *   **Desktop viewports ($\ge$ 900px)**: The navigation collapses into a left sidebar navigation panel (`_Sidebar`), featuring custom branding, active administrator profile parameters loaded from Firestore, vertical navigation links, and a bottom logout trigger.
    *   **Mobile viewports (< 900px)**: The navigation scales down to a bottom navigation bar displaying core tabs (Dashboard, Buses, Routes, and Profile).
*   **Sidebar Navigation Interceptor**: Rather than pushing full page routes on desktop (which hides the sidebar), `AdminDashboardScreen.navigateToTab` intercepts navigation links and switches the index of the primary `IndexedStack` to keep the shell persistent. On mobile, it falls back to standard pushes for native navigation flow.
*   **Dynamic Split Home Dashboard (`_AdminHomeTab`)**: On desktop, the dashboard splits into a 60% left column (Live Map Preview + Recent Trips) and a 40% right column (System Status alerts + Quick Actions grid). On mobile, it folds back to a single vertical scroll stream.
*   **Micro-Animations & Hover Effects**: Custom mouse tracking regions detect hovers, smoothly translating cards (Stats, Actions, Overview cards) up by 4px, intensifying drop shadows, and glowing border highlights.

---

## 🗄️ Firebase Database Schema

The portal syncs transport configurations across the following collections and nodes:

### Cloud Firestore (Master Configs)
*   **`users`**: Contains auth accounts and credentials mapping to roles:
    ```json
    {
      "id": "user_uid_123",
      "fullName": "Super Admin",
      "email": "admin@school.edu",
      "phone": "+1 555-0199",
      "role": "admin",
      "status": "active",
      "profileImageUrl": "...",
      "createdAt": "1710000000000",
      "updatedAt": "1710000000000"
    }
    ```
*   **`buses`**: Details active plates, fleet stats, driver links, and route links.
*   **`drivers`**: Details license IDs and assigned buses.
*   **`students`**: Details class sections, parent IDs, pickup/drop stop sequence, and route allocations.
*   **`parents`**: Maps children accounts and links settings.
*   **`routes`**: Identifies start/end locations and calculated times.
*   **`routeStops`**: Defines sequencings, coordinates (Lat/Long), and scheduled stop times.
*   **`assignments`**: Master collection binding Buses, Drivers, Routes, and Students.
*   **`trips`**: Logs current live trip metadata (`notStarted`, `onRoute`, `paused`, `completed`).
*   **`tripHistory`**: Permanent historical record of bus routes and arrival times.
*   **`emergencyAlerts`**: Warnings issued by active drivers or vehicles.

### Firebase Realtime Database (High-Frequency Coordinates)
*   **`liveLocations/{busId}`**: GPS NEO-6M nodes tracking moving coordinates:
    ```json
    {
      "latitude": 24.8607,
      "longitude": 67.0011,
      "speed": 32,
      "heading": 120,
      "tripId": "trip_98273",
      "updatedAt": 1710000000000
    }
    ```

---

## ⚡ Setup & Seeding Guide

### 1. Project Dependencies Installation
Make sure you have Flutter SDK installed. Inside the `admin_panel` directory, run:
```bash
flutter pub get
```

### 2. Programmatic CLI Admin User Creation
To populate Firestore and Firebase Auth with a default admin account without needing registration screens:
1. Run the Dart script in your terminal:
   ```bash
   dart scripts/create_admin.dart
   ```
2. The script prompts you to verify setup details.
3. Seeding yields the default testing account:
   *   **Email**: `admin@school.edu`
   *   **Password**: `admin123`

---

## 🛠️ Step-by-Step Backend Integration Roadmap

To connect the frontend dashboard widgets with the hardware GPS data, follow these integration steps:

### Step 1: Subscribe to the Live Locations Stream
Create a repository listener (`FirebaseDatabase.instance`) targeting the RTDB coordinates node:
```dart
FirebaseDatabase.instance.ref('liveLocations').onValue.listen((DatabaseEvent event) {
  final data = event.snapshot.value as Map<dynamic, dynamic>?;
  // Parse latitude, longitude, and speed updates
  // Update state to trigger map redraws
});
```

### Step 2: Render live OpenStreetMap markers (`flutter_map`)
Connect `flutter_map` inside `StaticMapPanel` and `AdminLiveTrackingScreen` using public tile layers. Feed the live coordinates stream to plot moving bus markers:
```dart
FlutterMap(
  options: MapOptions(initialCenter: LatLng(currentLat, currentLng), initialZoom: 13.0),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.example.admin_panel',
    ),
    MarkerLayer(
      markers: [
        Marker(
          point: LatLng(busLat, busLng),
          child: Icon(Icons.directions_bus_rounded, color: Colors.deepPurple, size: 30),
        ),
      ],
    ),
  ],
)
```

### Step 3: Implement Administrative Assignments
Complete the forms inside `AssignBusScreen` and `AddEditRouteScreen` to perform transactional writes updating `buses`, `routes`, and `assignments` collections simultaneously.

### Step 4: Integrate the Emergency Alert and Reports Logging
Hook a listener to the Firestore `/emergencyAlerts` collection. On changes, show popup dialogue alerts in the portal. Query completed trips in `/tripHistory` to compute statistics for on-time arrivals and log delays.

---

## 💻 Compilation & Deployment

*   **Run Locally**:
    ```bash
    flutter run -d chrome
    ```
*   **Compile Release Web Bundle**:
    ```bash
    flutter build web
    ```
    This produces optimized, tree-shaken static assets ready for deployment to static web hosts (e.g., Firebase Hosting, Vercel, Netlify) inside the `build/web/` directory.



1. Add Buses & Drivers (Fleet Management)
Routes to ban gaye, lekin un par gaari kon si chalegi aur chalayega kon?

Next Step: Manage Buses aur Manage Drivers screens par kaam karein. Yahan admin naye Buses (unke license plate, capacity) aur Drivers (naam, phone number, license detail) add karega.
2. Assign Bus & Driver to Route
Jab aapke paas Routes, Buses, aur Drivers teeno cheezain system mein mojud hon gi, to aapko unko aapas mein link karna hoga.

Next Step: Assign Bus screen (jo shayad pehlay se app mein mojud hai) ko set up karein. Is screen par admin batayega ke: "Bus No. 101, jise Driver Ali chala raha hai, wo 'Gulshan Express' Route par jayegi." Yeh assign karna Live Tracking ke liye sab se zaroori hai.
3. Manage Students & Parents
Jin logon ke liye yeh app ban rahi hai, unka data system mein aana chahiye.

Next Step: Manage Students aur Manage Parents screens. Yahan aap students add kar ke unko specific route ke specific "Stop" (pick/drop point) ke sath assign kar saktay hain. Taa ke parents ko exactly unke stop ke hisaab se notification milay.
4. Admin Live Tracking (Dashboard)
Jab sab assign hojaye, to final piece of the puzzle live tracking hai.

Next Step: Admin Live Tracking Screen jahan admin ek single map par apne tamaam buses ko live ghoomta hua dekh sakay (Firebase se driver app ki real-time location read kar ke).