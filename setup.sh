#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print header function
print_header() {
    echo -e "\n${BLUE}${BOLD}======================================${NC}"
    echo -e "${BLUE}${BOLD}   $1${NC}"
    echo -e "${BLUE}${BOLD}======================================${NC}\n"
}

# Print step function
print_step() {
    echo -e "${YELLOW}>> $1${NC}"
}

# Print success function
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Print error function
print_error() {
    echo -e "${RED}✗ $1${NC}"
    exit 1
}

# Print info function
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Format file size
format_size() {
    local size=$1
    if [ $size -ge 1048576 ]; then
        echo "$(printf "%.2f" $(echo "$size/1048576" | bc -l)) MB"
    elif [ $size -ge 1024 ]; then
        echo "$(printf "%.2f" $(echo "$size/1024" | bc -l)) KB"
    else
        echo "$size bytes"
    fi
}

# Check if Flutter is installed
check_flutter() {
    print_step "Checking Flutter installation..."
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter is not installed or not in PATH"
    else
        flutter_version=$(flutter --version | head -n 1)
        print_success "Flutter is installed: ${CYAN}$flutter_version${NC}"
    fi
}

# Clean the project
clean() {
    print_header "CLEANING PROJECT"
    print_step "Running flutter clean..."
    flutter clean || print_error "Failed to clean Flutter project"
    print_success "Flutter clean completed"
    
    # Show freed space
    print_info "Project cleaned. Build directory removed."
}

# Install dependencies
install_dependencies() {
    print_header "INSTALLING DEPENDENCIES"
    print_step "Running flutter pub get..."
    start_time=$(date +%s)
    flutter pub get || print_error "Failed to get dependencies"
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    print_success "Dependencies installed in ${CYAN}${duration}s${NC}"
    
    # Show dependency info
    dep_count=$(grep -c "^  " pubspec.lock)
    print_info "Total dependencies: ${CYAN}$dep_count${NC}"
}

# Generate l10n files
generate_l10n() {
    print_header "GENERATING L10N FILES"
    print_step "Running flutter gen-l10n..."
    start_time=$(date +%s)
    flutter gen-l10n || print_error "Failed to generate l10n files"
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    print_success "L10n files generated in ${CYAN}${duration}s${NC}"
    
    # Count generated files
    l10n_files=$(find lib/configs/l10n/generated -type f | wc -l | xargs)
    print_info "Generated ${CYAN}$l10n_files${NC} localization files"
}

# Generate ObjectBox files
generate_objectbox() {
    print_header "GENERATING OBJECTBOX FILES"
    print_step "Running flutter pub run build_runner build..."
    start_time=$(date +%s)
    flutter pub run build_runner build --delete-conflicting-outputs || print_error "Failed to generate ObjectBox files"
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    print_success "ObjectBox files generated in ${CYAN}${duration}s${NC}"
    
    # Show generated files
    if [ -f "lib/core/database/objectbox.g.dart" ]; then
        print_info "Generated: ${CYAN}lib/core/database/objectbox.g.dart${NC}"
    fi
}

# iOS Pod install
pod_install() {
    print_header "RUNNING POD INSTALL"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_step "Running pod install for iOS..."
        start_time=$(date +%s)
        cd ios && pod install && cd .. || print_error "Failed to install pods"
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        print_success "Pod install completed in ${CYAN}${duration}s${NC}"
        
        # Show pod info
        pod_count=$(grep -c "PODS:" ios/Podfile.lock)
        print_info "Total pods installed: ${CYAN}$pod_count${NC}"
    else
        print_step "Skipping pod install (not on macOS)"
    fi
}

# Build APK release
build_apk_release() {
    print_header "BUILDING APK RELEASE"
    print_step "Building release APK..."
    
    # Get app version from pubspec.yaml
    app_version=$(grep "version:" pubspec.yaml | head -n 1 | awk '{print $2}')
    app_name=$(grep "name:" pubspec.yaml | head -n 1 | awk '{print $2}')
    
    # Parse version name and version code
    version_name=$(echo "$app_version" | cut -d'+' -f1)
    version_code=$(echo "$app_version" | cut -d'+' -f2)
    
    print_info "Building ${CYAN}$app_name${NC} version ${CYAN}$version_name${NC} (build $version_code)"
    
    start_time=$(date +%s)
    flutter build apk --release || print_error "Failed to build APK"
    end_time=$(date +%s)
    build_duration=$((end_time - start_time))
    
    apk_path="build/app/outputs/flutter-apk/app-release.apk"
    
    if [ -f "$apk_path" ]; then
        # Get APK size
        apk_size=$(stat -f%z "$apk_path" 2>/dev/null || stat -c%s "$apk_path")
        formatted_size=$(format_size $apk_size)
        
        # Prepare destination folder and filename
        dest_dir="apk"
        mkdir -p "$dest_dir"
        datetime_str=$(date +"%Y-%m-%d %H.%M.%S")
        # Sanitize app_name for filename (remove slashes, etc.)
        safe_app_name=$(echo "$app_name" | sed 's/[^a-zA-Z0-9._-]/_/g')
        dest_apk_name="${safe_app_name} v${version_name} (${version_code}) - ${datetime_str}.apk"
        dest_apk_path="${dest_dir}/${dest_apk_name}"

        # Move and rename the APK
        mv "$apk_path" "$dest_apk_path" || print_error "Failed to move APK to $dest_apk_path"

        # Get APK info
        print_success "APK release build completed in ${CYAN}${build_duration}s${NC}"
        echo -e "\n${BOLD}${GREEN}APK BUILD DETAILS:${NC}"
        echo -e "${CYAN}• App Name:${NC} $app_name"
        echo -e "${CYAN}• Version Name:${NC} $version_name"
        echo -e "${CYAN}• Version Code:${NC} $version_code"
        echo -e "${CYAN}• Build Type:${NC} Release"
        echo -e "${CYAN}• APK Size:${NC} $formatted_size"
        echo -e "${CYAN}• Location:${NC} $(pwd)/$dest_apk_path"
        
        # Display QR code for download if qrencode is available
        if command -v qrencode &> /dev/null; then
            echo -e "\n${YELLOW}Scan to download APK:${NC}"
            qrencode -t ANSIUTF8 "file://$(pwd)/$dest_apk_path"
        fi
        
        echo -e "\n${GREEN}To install on a connected device:${NC}"
        echo -e "adb install -r $dest_apk_path"
    else
        print_error "APK file not found at expected location"
    fi
}

# Rebuild the project
rebuild() {
    start_time=$(date +%s)
    
    clean
    install_dependencies
    pod_install
    generate_l10n
    generate_objectbox
    
    end_time=$(date +%s)
    total_duration=$((end_time - start_time))
    print_header "REBUILD COMPLETED"
    print_success "Total rebuild time: ${CYAN}${total_duration}s${NC}"
}

# Show help
show_help() {
    echo -e "${BLUE}${BOLD}Invois Setup Script${NC}"
    echo -e "Usage: ./setup.sh [OPTION]"
    echo -e "\nOptions:"
    echo -e "  ${YELLOW}clean${NC}             - Clean the project"
    echo -e "  ${YELLOW}dependencies${NC}      - Install dependencies"
    echo -e "  ${YELLOW}l10n${NC}              - Generate localization files"
    echo -e "  ${YELLOW}objectbox${NC}         - Generate ObjectBox files"
    echo -e "  ${YELLOW}pods${NC}              - Run pod install for iOS"
    echo -e "  ${YELLOW}rebuild${NC}           - Clean and rebuild the project"
    echo -e "  ${YELLOW}apk${NC}               - Build release APK"
    echo -e "  ${YELLOW}all${NC}               - Run all operations"
    echo -e "  ${YELLOW}help${NC}              - Show this help message"
}

# Make the script executable
chmod +x "$0"

# Show script banner
echo -e "${BLUE}${BOLD}======================================${NC}"
echo -e "${BLUE}${BOLD}   INVOIS FLUTTER SETUP SCRIPT${NC}"
echo -e "${BLUE}${BOLD}======================================${NC}"
echo -e "${CYAN}Date:${NC} $(date)"
echo -e "${CYAN}OS:${NC} $(uname -s) $(uname -r)"

# Check if Flutter is installed
check_flutter

# Process arguments
if [ $# -eq 0 ]; then
    show_help
    exit 0
fi

case "$1" in
    clean)
        clean
        ;;
    dependencies)
        install_dependencies
        ;;
    l10n)
        generate_l10n
        ;;
    objectbox)
        generate_objectbox
        ;;
    pods)
        pod_install
        ;;
    rebuild)
        rebuild
        ;;
    apk)
        build_apk_release
        ;;
    all)
        start_time=$(date +%s)
        rebuild
        build_apk_release
        end_time=$(date +%s)
        total_duration=$((end_time - start_time))
        print_header "ALL OPERATIONS COMPLETED"
        print_success "Total execution time: ${CYAN}${total_duration}s${NC}"
        ;;
    help)
        show_help
        ;;
    *)
        echo -e "${RED}Invalid option: $1${NC}"
        show_help
        exit 1
        ;;
esac

echo -e "\n${GREEN}Script completed successfully!${NC}"
