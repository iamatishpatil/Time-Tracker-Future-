# Time Tracker Application

A full-stack application for tracking time, featuring a Flutter frontend and Node.js backend.

## Prerequisites
- Node.js installed
- Flutter SDK installed
- Android Emulator or Mobile Device (for mobile testing)

## Setup & Run

### 1. Backend
The backend runs on Node.js with Express and SQLite.

1. Open a terminal.
2. Navigate to the `backend` folder:
   ```bash
   cd backend
   ```
3. Install dependencies (if not already done):
   ```bash
   npm install
   ```
4. Start the server:
   ```bash
   node server.js
   ```
   The server will run at `http://localhost:3000`.

### 2. Frontend
The frontend is built with Flutter.

1. Open a new terminal.
2. Navigate to the `frontend` folder:
   ```bash
   cd frontend
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Features
- **Register**: Create an account with profile picture, role, and skills.
- **Login**: Secure login with mobile number and password.
- **Dashboard**: View profile details in a side drawer.

## Configuration
- **API URL**: Configured in `lib/services/api_service.dart`. Defaults to `http://localhost:3000/api`.
  - **Note**: If running on Android Emulator, change `localhost` to `10.0.2.2`.
