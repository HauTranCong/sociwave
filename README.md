# 🌊 SociWave

> **Automated Facebook Reel Comment Monitoring & Reply System**

A cross-platform Flutter web application for automated Facebook Reel comment management with customizable reply rules and real-time monitoring.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-production--ready-brightgreen.svg)](https://github.com/HauTranCong/sociwave)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](docker/)

---

## ✨ Features

- � **Full-Stack Application** - Flutter frontend with a powerful Python (FastAPI) backend.
- �🎬 **Reel Management** - Fetch and display all your Facebook video reels.
- 📝 **Comment Monitoring** - Real-time comment tracking.
- 🤖 **Automated Replies** - Customizable rules with keyword matching.
- 🔄 **24/7 Backend Monitoring** - A persistent backend service checks for new comments, so the app doesn't need to be open.
- 📊 **Dashboard** - View statistics and monitoring status at a glance.
- 🔐 **Secure API Integration** - All Facebook Graph API calls are handled by the backend.
- 🎨 **Modern UI** - Clean, responsive Material Design interface.
- � **Docker Ready** - Fully containerized frontend and backend for easy deployment.
- 🌐 **PWA Support** - Install the web app on mobile/desktop.

---

## 📁 Project Structure

```
sociwave/
├── backend/               # FastAPI backend
│   ├── app/               # Core app package
│   │   ├── api/           # FastAPI routers
│   │   ├── core/          # settings, database, config
│   │   ├── models/        # Pydantic + SQLAlchemy models
│   │   └── services/      # business logic and schedulers
│   ├── docs/              # backend-specific docs/diagrams
│   ├── scripts/           # helper scripts (e.g., create_user.py, test_api.py)
│   ├── data/              # local SQLite database
│   ├── main.py            # backend entrypoint
│   ├── Dockerfile
│   └── requirements.txt
├── webapp/                # Flutter web application
│   ├── lib/               # UI, state management, services
│   ├── web/               # web assets and config
│   ├── test/              # widget/unit tests
│   └── pubspec.yaml
├── docker/                # Docker configuration (compose, Nginx)
├── docs/                  # architecture and deployment docs
├── scripts/               # top-level build/deploy scripts
├── deploy.sh              # deployment helper
└── README.md              # this file
```

---

## 🚀 Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- [Python](https://www.python.org/downloads/) (3.9 or higher)
- [Docker](https://www.docker.com/products/docker-desktop) (for containerized deployment)
- Facebook App with Graph API access

### Running the Full Application (Frontend + Backend)

The easiest way to run the entire application is with Docker Compose.

1. **Clone the repository:**
   ```bash
   git clone https://github.com/HauTranCong/sociwave.git
   cd sociwave
   ```

2. **Configure the backend:**
   - Open `backend/scripts/test_api.py` and replace `"YOUR_ACCESS_TOKEN"` and `"YOUR_PAGE_ID"` with your Facebook credentials.

3. **Run with Docker Compose:**
   ```bash
   docker-compose -f docker/docker-compose.yml up --build -d
   ```

4. **Initialize the backend configuration:**
   ```bash
   # This script will save your credentials to the backend's database
   docker-compose -f docker/docker-compose.yml exec sociwave-backend python scripts/test_api.py
   ```

**Access the application:** http://localhost:8080

### Manual Setup

If you prefer to run the frontend and backend separately without Docker:

1.  **Run the Backend:**
    ```bash
    cd backend
    python -m venv .venv
    # Activate the virtual environment (Windows)
    .venv\Scripts\activate.bat
    # Or on macOS/Linux
    # source .venv/bin/activate
    pip install -r requirements.txt
    uvicorn main:app --reload
    ```

2.  **Run the Frontend:**
    ```bash
    cd webapp
    flutter pub get
    flutter run -d chrome --web-port 8080
    ```

---

## 🐳 Docker Deployment

The application is fully containerized. The `docker-compose.yml` file in the `docker` directory will build and run both the Flutter web app (served with Nginx) and the FastAPI backend.

```bash
# Build and run both services in detached mode
docker-compose -f docker/docker-compose.yml up --build -d

# Stop the services
docker-compose -f docker/docker-compose.yml down
```

For more detailed instructions, see [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md).
---

## 📱 Application Screens

### 1. 🔐 Login Screen
- Facebook authentication
- Token management
- Profile information display

### 2. 📊 Dashboard
- Monitoring statistics
- Active reels count
- Background service status
- Quick access to all features

### 3. 🎬 Reels Screen
- Card-based reel display
- Fetch all video reels
- View reel details
- Navigate to comments

### 4. 💬 Comments Screen
- Real-time comment updates
- Auto-refresh (30 seconds)
- Pull-to-refresh support
- Reply to comments manually
- View automated reply status

### 5. 📋 Rules Screen
- Create custom reply rules
- Keyword-based conditions
- Edit/delete rules
- Enable/disable rules
- Rule priority management

### 6. ⚙️ Settings
- Background monitoring toggle
- Refresh interval configuration
- API token management
- App information
- Logout functionality

---

## 🔧 Configuration

### Facebook API Setup

1. Create a Facebook App at [developers.facebook.com](https://developers.facebook.com/)
2. Add "pages_show_list", "pages_read_engagement", "pages_manage_posts" permissions
3. Generate a Page Access Token
4. Copy the token to SociWave settings

### Application Settings

- **Auto-refresh interval:** 30 seconds (customizable)
- **Background monitoring:** 5 minutes (customizable)
- **Token storage:** Secure local storage
- **API version:** Facebook Graph API v12.0+

---

## 🏗️ Architecture

### Technology Stack

- **Frontend:** Flutter 3.x (Dart)
- **Backend:** Python 3.9+ with FastAPI
- **Database:** SQLite (via SQLAlchemy)
- **State Management:** Provider
- **Routing:** GoRouter
- **HTTP Client:** Dio
- **Deployment:** Docker + Nginx

### Design Patterns

- **Full-Stack Clean Architecture** - Separation of concerns across frontend and backend.
- **Repository Pattern** - Data abstraction.
- **Provider Pattern** - State management in Flutter.
- **Service Layer** - Business logic isolation in both frontend and backend.

### Code Quality

- ✅ Clean architecture principles applied to both Flutter and FastAPI.
- ✅ Comprehensive logging.
- ✅ Secure token management handled by the backend.
- ✅ Asynchronous task handling for non-blocking monitoring.

---

## 📚 Documentation

- [**ARCHITECTURE_DESIGN.md**](docs/ARCHITECTURE_DESIGN.md) - System architecture and design
- [**DEPLOYMENT_GUIDE.md**](docs/DEPLOYMENT_GUIDE.md) - Deploy to Netlify, Vercel, or GitHub Pages
- [**DOCKER_DEPLOYMENT.md**](docs/DOCKER_DEPLOYMENT.md) - Complete Docker deployment guide
- [**PROJECT_STATUS.md**](docs/PROJECT_STATUS.md) - Current project status and decisions

---

## 🚀 Deployment Options

### 1. Static Hosting (Recommended for Web-Only)

Deploy the `webapp/build/web` folder to:

- **Netlify** - Zero-config deployment
- **Vercel** - Automatic builds from Git
- **GitHub Pages** - Free hosting for public repos
- **Firebase Hosting** - Google's hosting platform

See [DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md) for step-by-step instructions.

### 2. Docker Deployment (Recommended for Production)

Deploy the Docker container to:

- **AWS ECS/Fargate** - Managed container service
- **Google Cloud Run** - Serverless containers
- **DigitalOcean App Platform** - Simple deployment
- **Azure Container Instances** - Microsoft's container service

See [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md) for detailed guides.

### 3. VPS Deployment

Deploy to traditional VPS:

- Build with Docker and deploy via SSH
- Use Docker Compose for orchestration
- Set up Nginx as reverse proxy (if not using Docker)

### 4. Single-Server (All-in-One) Deployment

Serve the Flutter frontend and FastAPI backend from the same machine with Docker Compose:

1. Point the web bundle to the publicly reachable backend URL: `export API_BASE_URL="https://your-domain.com/api"` (or protocol/port that matches your server). This value is passed into the Flutter build and baked into the static assets.
2. Allow the backend to accept browser calls from that origin: `export FRONTEND_ORIGINS="https://your-domain.com"`. Multiple origins can be comma-separated.
3. Build and start both services: `docker compose -f docker/docker-compose.yml up -d --build`.
4. Open ports 80 (frontend via Nginx) and 8000 (FastAPI) in your firewall/security group, or front the stack with a reverse proxy/SSL terminator of your choice.
5. Browse to `https://your-domain.com` (or `http://your-domain.com:8080` if you keep the default port mapping) and the web app will call the backend on the same host without CORS issues.

---

## ⚠️ Important Notes

### Browser-Based Monitoring

This is a **Flutter web application** that runs entirely in the browser. The monitoring service requires the browser to remain open:

- ✅ Works while browser tab is open
- ❌ Stops when browser is closed
- ❌ Requires device to stay on

### 24/7 Monitoring (Future Enhancement)

For true 24/7 monitoring without keeping the browser open, consider adding a backend server (see [docs/PROJECT_STATUS.md](docs/PROJECT_STATUS.md) for details).

---

## 🧪 Testing

```bash
cd webapp

# Run all tests
flutter test

# Run specific test file
flutter test test/providers/config_provider_test.dart

# Run with coverage
flutter test --coverage
```

---

## 🛠️ Development

### Running Tests

```bash
flutter test
```

### Code Generation (if using build_runner)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Analyzing Code

```bash
flutter analyze
```

### Formatting Code

```bash
flutter format lib/
```

---

## 📈 Project Stats

- **Platform:** Flutter Web (with mobile support)
- **Code Lines:** 6,500+ lines
- **Dart Files:** 39 files
- **Screens:** 6
- **Widgets:** 8+ custom widgets
- **Providers:** 6 state providers
- **Services:** 4 core services
- **Build Size:** ~31MB (optimized)

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- Flutter Team for the amazing framework
- Facebook Graph API for the API access
- All open-source contributors

---

## 📧 Contact

- **Author:** Hau Tran Cong
- **GitHub:** [@HauTranCong](https://github.com/HauTranCong)
- **Repository:** [sociwave](https://github.com/HauTranCong/sociwave)

---

**Made with ❤️ using Flutter**
