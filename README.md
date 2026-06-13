# BLT - Bus Location Tracker

## Final Next Version Plan

BLT is a professional school and college bus tracking system for Admin, Driver, Parent, and Student users. The next version will complete the full frontend and backend flow: GPS hardware sends bus location to Firebase in real time, and the Flutter mobile app shows live tracking, ETA, alerts, history, and role-based dashboards.

This plan is based on the current app flow plus the project presentation requirements:

- Real-time GPS tracking for school and college buses
- GPS Module NEO-6M connected with NodeMCU ESP8266
- NodeMCU sends coordinates through WiFi
- Firebase stores and syncs data in real time
- Flutter app displays current user and bus locations using OpenStreetMap
- Parents and students receive ETA, safety updates, and notifications

---

# 1. Product Goal

Build a clean, modern, production-level transport app that reduces waiting time, improves student safety, and digitizes school transport management.

## Main Problems

- Parents wait without knowing the bus arrival time
- Students face delays and safety concerns
- Schools lack real-time bus monitoring
- Manual communication causes confusion

## Main Solution

- Install GPS hardware in every bus
- Send live latitude and longitude to Firebase
- Show live bus movement in the mobile app
- Notify parents and students when the bus starts, arrives, or is near
- Give admins a complete system for buses, routes, drivers, parents, and students

---

# 2. App Theme

## Colors

- Primary: Blue
- Secondary: Yellow / Orange
- Success: Green
- Danger: Red
- Background: White / Light Grey
- Text: Dark Navy / Black

## UI Style

- Material 3 design
- Modern cards
- Rounded corners
- Clean typography
- OpenStreetMap tracking screens
- School transport feel
- Simple role-based navigation
- Responsive mobile layouts

---

# 3. Technology Stack

## Frontend

- Flutter
- Dart
- Material 3
- OpenStreetMap UI with `flutter_map`
- Role-based navigation
- Reusable widgets for buttons, text fields, status chips, cards, loading, empty, and error states

## Backend

- Firebase Authentication
- Cloud Firestore for users, buses, routes, assignments, profiles, history, and reports
- Firebase Realtime Database for live bus coordinates
- Firebase Cloud Messaging for push notifications
- Firebase Cloud Functions for ETA, alerts, geofence checks, and trip automation
- Firebase Storage for profile images and optional documents

## Hardware

- GPS Module NEO-6M
- NodeMCU ESP8266
- Connecting wires
- WiFi network
- Arduino IDE firmware

## Map And Location Packages

- `flutter_map` for OpenStreetMap tiles
- `latlong2` for map coordinates
- `geolocator` for GPS location data
- `permission_handler` for Android and iOS permission handling

## OpenStreetMap Setup

No map API key is required. The app uses public OpenStreetMap tiles through `flutter_map`.

For production scale, use a proper tile provider or your own tile server and follow the provider's usage policy.

---

# 4. Complete System Architecture

```txt
GPS Satellite
↓
NEO-6M GPS Module inside bus
↓
NodeMCU ESP8266 reads latitude and longitude
↓
NodeMCU sends data through WiFi
↓
Firebase Realtime Database stores live location
↓
Cloud Functions process ETA, geofence, and alerts
↓
Flutter mobile app listens to Firebase
↓
Users see live bus map, ETA, notifications, and history
```

---

# 5. Authentication And Role Flow

## Splash Screen

- Show app logo
- Show app name: BLT Bus Location Tracker
- Show tagline: Track your bus in real time
- Check login status

```txt
Splash
↓
Not logged in → Onboarding
Logged in → Role check → Dashboard
```

## Onboarding

1. Track Your Bus Live
   - View real-time bus location
2. Stay Safe and Updated
   - Get instant bus alerts
3. Complete Transport System
   - Built for parents, students, drivers, and admins

## Login

- Email
- Password
- Forgot password
- Create account
- Role is detected from Firebase after login

```txt
Login success
↓
Read user role from Firestore
↓
Admin → Admin Dashboard
Driver → Driver Dashboard
Parent → Parent Dashboard
Student → Student Dashboard
```

## Register

- Full name
- Email
- Phone number
- Password
- Confirm password
- Role dropdown:
  - Parent
  - Student
  - Driver
  - Admin

## Forgot Password

- Email field
- Send reset link button

---

# 6. Frontend Modules

## Admin App

### Admin Dashboard

- Welcome Admin
- School name
- Today date
- Total buses
- Active buses
- Total drivers
- Total students
- Total routes
- Live bus map preview
- Recent trips
- Emergency alerts

### Admin Screens

- Manage Buses
- Add / Edit Bus
- Manage Drivers
- Add / Edit Driver
- Manage Students
- Add / Edit Student
- Manage Parents
- Manage Routes
- Add / Edit Route
- Assign Bus
- Admin Live Tracking
- Reports
- Profile

### Admin Bottom Navigation

- Dashboard
- Buses
- Routes
- Profile

## Driver App

### Driver Dashboard

- Driver name
- Assigned bus
- Route name
- Trip status
- Start Trip button
- End Trip button
- GPS status
- Location sharing status

### Driver Screens

- Start Trip
- Route Stops
- Emergency Alert
- Trip History
- Profile

### Driver Bottom Navigation

- Dashboard
- Route
- Emergency
- Profile

## Parent App

### Parent Dashboard

- Welcome Parent
- Children selector
- Notification icon
- Child card
- Bus status card
- Track Live Bus button
- Quick actions
- Logout option in Profile tab

### Parent Screens

- Children
- Live Tracking
- Notifications
- Trip History
- Profile

### Parent Bottom Navigation

- Home
- Children
- Tracking
- Profile

## Student App

### Student Dashboard

- Welcome Student
- Student name
- Class / Section
- Assigned bus
- Route name
- Driver name
- ETA
- Bus status
- Track My Bus button
- Quick actions

### Student Screens

- Live Tracking
- Route Stops
- Notifications
- Trip History
- Profile

### Student Bottom Navigation

- Home
- Tracking
- History
- Profile

---

# 7. Backend Data Model

## users

- id
- fullName
- email
- phone
- role: admin | driver | parent | student
- status
- profileImageUrl
- createdAt
- updatedAt

## schools

- id
- name
- address
- contactPhone
- adminIds

## buses

- id
- busNumber
- plateNumber
- capacity
- status: active | offline | maintenance
- assignedDriverId
- assignedRouteId
- lastLocation
- lastUpdated

## drivers

- id
- userId
- licenseNumber
- assignedBusId
- status
- phone

## students

- id
- userId
- fullName
- className
- section
- parentIds
- assignedBusId
- assignedRouteId
- pickupStopId
- dropStopId
- status

## parents

- id
- userId
- childrenIds
- notificationSettings

## routes

- id
- name
- startPoint
- endPoint
- assignedBusId
- estimatedDuration
- status

## routeStops

- id
- routeId
- stopName
- latitude
- longitude
- pickupTime
- sequence
- status

## assignments

- id
- busId
- driverId
- routeId
- studentIds
- activeFrom
- activeTo
- status

## liveLocations

Use Firebase Realtime Database for fast updates:

```txt
liveLocations/{busId}
  latitude
  longitude
  speed
  heading
  accuracy
  tripId
  updatedAt
```

## trips

- id
- busId
- driverId
- routeId
- status: notStarted | onRoute | paused | completed
- startedAt
- endedAt
- totalStopsCompleted
- distance

## tripHistory

- id
- tripId
- studentId
- busId
- routeId
- pickupTime
- arrivalTime
- status

## notifications

- id
- userId
- title
- body
- type
- isRead
- createdAt
- relatedTripId

## emergencyAlerts

- id
- driverId
- busId
- type
- message
- latitude
- longitude
- status
- createdAt

## attendance

Future enhancement:

- id
- studentId
- tripId
- busId
- method: fingerprint | manual | qr
- boardedAt
- droppedAt
- status

---

# 8. Backend Services

## Auth Service

- Register users
- Login users
- Reset password
- Read role from Firestore
- Route user to correct dashboard
- Logout

## Bus Service

- Create bus
- Update bus
- Assign driver
- Assign route
- Update bus status
- Read active buses

## Location Service

- Listen to live bus coordinates
- Save live location from hardware
- Validate stale/offline locations
- Store last known bus location

## Route Service

- Create and update routes
- Add stops
- Sort stops by sequence
- Calculate route progress

## Trip Service

- Start trip
- Pause trip
- End trip
- Save trip history
- Calculate completed stops

## Notification Service

- Bus started
- Bus near pickup stop
- Bus arrived
- Bus reached school
- Delay alert
- Emergency alert

## ETA Service

- Calculate ETA using latest location and route stops
- Recalculate when bus moves
- Save ETA per stop
- Show ETA to parents and students

## Geofence Service

- Home geofence
- Pickup stop geofence
- School geofence
- Auto-trigger arrival/departure notifications

## Report Service

- Trip reports
- Attendance reports
- Bus utilization
- Delay reports
- Emergency reports

---

# 9. Hardware Firmware Plan

## NodeMCU Responsibilities

- Connect to WiFi
- Read GPS data from NEO-6M
- Parse latitude and longitude
- Send data to Firebase Realtime Database
- Include busId, speed, heading, and timestamp
- Retry when WiFi is disconnected
- Mark bus offline when no update is received

## Firmware Data Payload

```json
{
  "busId": "bus_12",
  "latitude": 24.8607,
  "longitude": 67.0011,
  "speed": 32,
  "heading": 120,
  "updatedAt": 1710000000000
}
```

---

# 10. Security Plan

## Firebase Rules

- Admin can read/write all school transport data
- Driver can update assigned bus location and trip status
- Parent can read only assigned children, buses, trips, and notifications
- Student can read only their own bus, route, notifications, and history
- No user can read unrelated private profiles

## Validation

- Validate role before dashboard access
- Validate assignment before showing bus data
- Validate driver before accepting live location updates
- Reject invalid coordinates
- Prevent client-side privilege escalation

---

# 11. Future Enhancements

These are planned after the core next version:

- Fingerprint-based attendance when students board the bus
- iOS version
- ETA calculation for every bus stop
- Push notifications for parents and students
- Geofencing for home, school, and pickup points
- Bus arrival and departure history tracking
- Emergency alert button for drivers or students
- Offline cache for recent route and bus data
- QR attendance fallback
- Admin web dashboard

---

# 12. Development Roadmap

## Phase 1: Frontend Completion

- Finalize all role dashboards
- Polish auth screens
- Complete profile and logout flows
- Complete loading, empty, and error states
- Make all screens responsive
- Add professional map placeholder states for no API key

## Phase 2: Firebase Backend

- Configure Firebase project
- Add Firebase Auth
- Create Firestore collections
- Create Realtime Database structure
- Add repository/service layer
- Implement role-based routing from Firestore
- Add security rules

## Phase 3: Live Tracking

- Connect OpenStreetMap using `flutter_map`
- Listen to live bus location
- Draw route polyline
- Show bus marker, pickup marker, and school marker
- Add ETA display
- Add stale/offline bus state

## Phase 4: Driver Trip Flow

- Start trip
- End trip
- Update trip status
- Update live location
- Mark route stops
- Send emergency alerts

## Phase 5: Notifications And History

- Add Firebase Cloud Messaging
- Add bus started / near / arrived / reached school notifications
- Save notification history
- Save trip history
- Add delay and emergency alerts

## Phase 6: Hardware Integration

- Write NodeMCU firmware
- Connect NEO-6M GPS
- Send test coordinates to Firebase
- Test moving bus simulation
- Validate update interval and offline state

## Phase 7: QA And Release

- Unit tests
- Widget tests
- Firebase rules tests
- Real device testing
- Map API testing
- Driver route test
- Parent and student notification test
- Android release build

---

# 13. Completion Checklist

## Frontend

- Splash screen
- Onboarding screens
- Login screen
- Register screen
- Forgot password screen
- Admin dashboard and management screens
- Driver dashboard and trip screens
- Parent dashboard, children, tracking, history, profile
- Student dashboard, tracking, route stops, notifications, history, profile
- Edit profile
- Logout from every role profile

## Backend

- Firebase Auth
- Firestore schema
- Realtime Database live locations
- Cloud Messaging
- Cloud Functions
- OpenStreetMap / `flutter_map`
- Role-based access
- Security rules
- Repository layer
- Error handling

## Hardware

- GPS module connected
- NodeMCU firmware
- WiFi setup
- Firebase live update
- Bus offline detection
- Real route test

---

# 14. Final Navigation Flow

```txt
Splash
↓
Onboarding
↓
Login / Register
↓
Role Check
↓
Admin Dashboard
  ↓ Manage Buses
  ↓ Manage Drivers
  ↓ Manage Students
  ↓ Manage Parents
  ↓ Manage Routes
  ↓ Assign Bus
  ↓ Live Tracking
  ↓ Reports
  ↓ Profile / Logout

Driver Dashboard
  ↓ Start Trip
  ↓ Route Stops
  ↓ Emergency Alert
  ↓ Trip History
  ↓ Profile / Logout

Parent Dashboard
  ↓ Children
  ↓ Live Tracking
  ↓ Notifications
  ↓ Trip History
  ↓ Profile / Logout

Student Dashboard
  ↓ Live Tracking
  ↓ Route Stops
  ↓ Notifications
  ↓ Trip History
  ↓ Profile / Logout
```
