# 🌊 SociWave

> **Automated Facebook Reel Comment Monitoring & Reply System**

A cross-platform Flutter web application for automated Facebook Reel comment management with customizable reply rules and real-time monitoring.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-production--ready-brightgreen.svg)](https://github.com/HauTranCong/sociwave)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](docker/)

---

## ✨ Features

- 🎬 **Reel Management** - Fetch and display all your Facebook video reels as cards
- 📝 **Comment Monitoring** - Real-time comment tracking with auto-refresh (30s)
- 🤖 **Automated Replies** - Customizable rules with keyword matching and conditions
- 🔄 **Background Monitoring** - Check for new comments every 5 minutes
- 📊 **Dashboard** - View statistics and monitoring status at a glance
- 🔐 **Secure API Integration** - Facebook Graph API with token management
- 🎨 **Modern UI** - Clean, responsive Material Design interface
- 🚀 **Multiple Refresh Methods** - Manual, pull-to-refresh, auto-refresh, background
- 🐳 **Docker Ready** - Containerized deployment with optimized Nginx
- 🌐 **PWA Support** - Install as Progressive Web App on mobile/desktop

---

## 📁 Project Structure

```
sociwave/
├── webapp/              # Flutter application source code
│   ├── lib/             # Main application code (6,500+ lines)
│   │   ├── main.dart
│   │   ├── core/        # Core utilities and base classes
│   │   ├── data/        # Data layer (services, repositories)
│   │   ├── domain/      # Domain layer (models, entities)
│   │   ├── providers/   # State management (Riverpod)
│   │   ├── router/      # Navigation and routing
│   │   ├── screens/     # UI screens (Dashboard, Comments, Settings)
│   │   ├── services/    # Business logic services
│   │   ├── theme/       # App theming
│   │   └── widgets/     # Reusable UI components
│   ├── web/             # Web-specific assets
│   │   ├── index.html   # SEO-optimized HTML
│   │   ├── manifest.json # PWA manifest
│   │   └── icons/       # PWA icons
│   ├── build/web/       # Production build (31MB, ready to deploy)
│   └── pubspec.yaml     # Dependencies
├── docker/              # Docker configuration files
│   ├── Dockerfile       # Multi-stage build (Flutter + Nginx)
│   ├── docker-compose.yml # Orchestration with health checks
│   ├── nginx.conf       # Production Nginx config
│   └── .dockerignore    # Build optimization
├── docs/                # Comprehensive documentation
│   ├── ARCHITECTURE_DESIGN.md   # System architecture & design
│   ├── DEPLOYMENT_GUIDE.md      # Deploy to Netlify/Vercel/GitHub Pages
│   ├── DOCKER_DEPLOYMENT.md     # Docker deployment guide
│   └── PROJECT_STATUS.md        # Current status & tech decisions
├── scripts/             # Build and deployment automation
│   ├── build.sh         # Flutter build script
│   ├── docker-build.sh  # Docker build shortcut
│   └── docker-deploy.sh # Interactive Docker deployment
└── README.md            # This file
```

---

## 🚀 Quick Start

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.x or higher)
- [Dart SDK](https://dart.dev/get-dart) (3.x or higher)
- Facebook App with Graph API access
- Web browser (Chrome, Firefox, Safari, or Edge)
- Docker (optional, for containerized deployment)

### Installation

1. **Clone the repository:**

```bash
git clone https://github.com/HauTranCong/sociwave.git
cd sociwave/webapp
```

2. **Install dependencies:**

```bash
flutter pub get
```

3. **Run the app:**

```bash
# Development mode with hot reload
flutter run -d chrome --web-port 8080

# Or run on local web server
flutter run -d web-server --web-port 8080
```

**Access:** http://localhost:8080

### Building for Production

```bash
cd webapp

# Build optimized production version
flutter build web --release --tree-shake-icons

# Serve locally for testing
cd build/web
python3 -m http.server 8000
```

**Access:** http://localhost:8000

---

## 🐳 Docker Deployment

### Quick Start with Docker

```bash
# Build and run with Docker Compose
docker-compose up -d

# Access the application
open http://localhost:8080
```

### Manual Docker Build

```bash
# Build the Docker image
docker build -t sociwave:latest -f docker/Dockerfile .

# Run the container
docker run -d -p 8080:80 --name sociwave sociwave:latest

# View logs
docker logs -f sociwave
```

### Interactive Deployment Script

```bash
# Use the interactive deployment menu
./scripts/docker-deploy.sh
```

**Docker Features:**

- ✅ Multi-stage build (~40MB final image)
- ✅ Nginx with gzip compression
- ✅ Static asset caching (1 year)
- ✅ Health checks & auto-restart
- ✅ Security headers

For detailed Docker deployment instructions, see [DOCKER_DEPLOYMENT.md](docs/DOCKER_DEPLOYMENT.md).

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
- **State Management:** Riverpod
- **Routing:** GoRouter
- **HTTP Client:** Dio
- **Storage:** Shared Preferences
- **Deployment:** Docker + Nginx

### Design Patterns

- **Clean Architecture** - Separation of concerns
- **Repository Pattern** - Data abstraction
- **Provider Pattern** - State management
- **Service Layer** - Business logic isolation

### Code Quality

- ✅ 0 compilation errors
- ✅ 0 critical warnings
- ✅ Clean architecture principles
- ✅ Comprehensive logging
- ✅ Secure token management

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
