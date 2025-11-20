#!/bin/bash

# ===================================
# SociWave Docker Deployment Script
# ===================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="sociwave-web"
CONTAINER_NAME="sociwave-web"
PORT="8080"

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed!"
        echo "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    print_success "Docker is installed"
}

# Check if Docker Compose is installed
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_warning "Docker Compose is not installed!"
        echo "Using docker commands instead..."
        USE_COMPOSE=false
    else
        print_success "Docker Compose is installed"
        USE_COMPOSE=true
    fi
}

# Build the Docker image
build_image() {
    print_header "Building Docker Image"
    
    if [ "$USE_COMPOSE" = true ]; then
        print_info "Building with Docker Compose..."
        docker-compose -f docker/docker-compose.yml build
    else
        print_info "Building with Docker..."
        docker build -f docker/Dockerfile -t $IMAGE_NAME:latest .
    fi
    
    print_success "Image built successfully"
}

# Stop and remove existing container
stop_container() {
    print_header "Stopping Existing Container"
    
    if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
        print_info "Stopping container..."
        docker stop $CONTAINER_NAME
        print_success "Container stopped"
    else
        print_info "No running container found"
    fi
    
    if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
        print_info "Removing container..."
        docker rm $CONTAINER_NAME
        print_success "Container removed"
    fi
}

# Start the container
start_container() {
    print_header "Starting Container"
    
    if [ "$USE_COMPOSE" = true ]; then
        print_info "Starting with Docker Compose..."
        docker-compose -f docker/docker-compose.yml up -d
    else
        print_info "Starting with Docker..."
        docker run -d \
            --name $CONTAINER_NAME \
            -p $PORT:80 \
            --restart unless-stopped \
            $IMAGE_NAME:latest
    fi
    
    print_success "Container started"
}

# Check container health
check_health() {
    print_header "Checking Container Health"
    
    print_info "Waiting for container to be healthy..."
    sleep 5
    
    HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_NAME 2>/dev/null || echo "unknown")
    
    if [ "$HEALTH_STATUS" = "healthy" ]; then
        print_success "Container is healthy"
    elif [ "$HEALTH_STATUS" = "starting" ]; then
        print_warning "Container is still starting..."
        print_info "Check health with: docker ps"
    else
        print_warning "Health check not available or failed"
        print_info "Check logs with: docker logs $CONTAINER_NAME"
    fi
}

# Show deployment info
show_info() {
    print_header "Deployment Information"
    
    echo ""
    echo "🎉 SociWave is now running!"
    echo ""
    echo -e "${GREEN}Access URL:${NC} http://localhost:$PORT"
    echo ""
    echo "Useful commands:"
    echo -e "  ${BLUE}View logs:${NC}       docker logs -f $CONTAINER_NAME"
    echo -e "  ${BLUE}Stop container:${NC}  docker stop $CONTAINER_NAME"
    echo -e "  ${BLUE}Restart:${NC}         docker restart $CONTAINER_NAME"
    echo -e "  ${BLUE}Check status:${NC}    docker ps | grep $CONTAINER_NAME"
    echo ""
    
    if [ "$USE_COMPOSE" = true ]; then
        echo "Or with Docker Compose:"
        echo -e "  ${BLUE}View logs:${NC}       docker-compose -f docker/docker-compose.yml logs -f"
        echo -e "  ${BLUE}Stop:${NC}            docker-compose -f docker/docker-compose.yml down"
        echo -e "  ${BLUE}Restart:${NC}         docker-compose -f docker/docker-compose.yml restart"
        echo ""
    fi
}

# View logs
view_logs() {
    print_header "Container Logs"
    
    if [ "$USE_COMPOSE" = true ]; then
        docker-compose -f docker/docker-compose.yml logs -f
    else
        docker logs -f $CONTAINER_NAME
    fi
}

# Main menu
show_menu() {
    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}SociWave Docker Deployment${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo "1) Deploy (Build + Run)"
    echo "2) Build only"
    echo "3) Start container"
    echo "4) Stop container"
    echo "5) Restart container"
    echo "6) View logs"
    echo "7) Check status"
    echo "8) Clean up (Remove all)"
    echo "9) Exit"
    echo ""
    read -p "Select option: " choice
    
    case $choice in
        1) deploy ;;
        2) build_image ;;
        3) start_container ;;
        4) stop_container ;;
        5) restart_container ;;
        6) view_logs ;;
        7) check_status ;;
        8) cleanup ;;
        9) exit 0 ;;
        *) print_error "Invalid option"; show_menu ;;
    esac
}

# Full deployment
deploy() {
    check_docker
    check_docker_compose
    build_image
    stop_container
    start_container
    check_health
    show_info
}

# Restart container
restart_container() {
    print_header "Restarting Container"
    
    if [ "$USE_COMPOSE" = true ]; then
        docker-compose -f docker/docker-compose.yml restart
    else
        docker restart $CONTAINER_NAME
    fi
    
    print_success "Container restarted"
}

# Check status
check_status() {
    print_header "Container Status"
    
    if [ "$USE_COMPOSE" = true ]; then
        docker-compose -f docker/docker-compose.yml ps
    else
        docker ps -a | grep $CONTAINER_NAME || echo "Container not found"
    fi
    
    echo ""
    print_info "Detailed status:"
    docker inspect --format='{{.State.Status}}' $CONTAINER_NAME 2>/dev/null || echo "Container not found"
}

# Clean up
cleanup() {
    print_header "Cleaning Up"
    
    read -p "This will remove the container and image. Continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stop_container
        
        print_info "Removing image..."
        docker rmi $IMAGE_NAME:latest 2>/dev/null || print_warning "Image not found"
        
        print_success "Cleanup complete"
    else
        print_info "Cleanup cancelled"
    fi
}

# Parse command line arguments
if [ $# -eq 0 ]; then
    show_menu
else
    case $1 in
        deploy) deploy ;;
        build) check_docker; check_docker_compose; build_image ;;
        start) check_docker; check_docker_compose; start_container ;;
        stop) stop_container ;;
        restart) restart_container ;;
        logs) view_logs ;;
        status) check_status ;;
        clean) cleanup ;;
        *)
            echo "Usage: $0 {deploy|build|start|stop|restart|logs|status|clean}"
            echo ""
            echo "Commands:"
            echo "  deploy  - Build and run the container"
            echo "  build   - Build the Docker image"
            echo "  start   - Start the container"
            echo "  stop    - Stop the container"
            echo "  restart - Restart the container"
            echo "  logs    - View container logs"
            echo "  status  - Check container status"
            echo "  clean   - Remove container and image"
            exit 1
            ;;
    esac
fi
