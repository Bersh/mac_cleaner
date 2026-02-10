#!/bin/bash
# =============================================================================
# macOS System Data Storage Audit Script
# Scans common locations that inflate "System Data" in macOS storage settings
# Focus: developer tools, caches, build artifacts
#
# This script is READ-ONLY — it does not delete anything.
# https://github.com/Bersh/mac_cleaner
# =============================================================================

set -euo pipefail

VERSION="1.0.0"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Audits storage on a developer's macOS machine. Scans common locations
that inflate "System Data" — caches, build artifacts, Docker, IDEs,
package managers — and reports sizes with cleanup instructions.

This script is read-only. It does not delete anything.

Options:
  --no-color    Disable colored output (useful for piping or logging)
  --help        Show this help message
  --version     Show version

Examples:
  $(basename "$0")              # Run the audit
  $(basename "$0") --no-color   # Plain text output
  sudo $(basename "$0")         # Better accuracy for system directories
EOF
    exit 0
}

# Parse arguments
NO_COLOR=false
for arg in "$@"; do
    case "$arg" in
        --help|-h)    usage ;;
        --version|-v) echo "mac_storage_audit $VERSION"; exit 0 ;;
        --no-color)   NO_COLOR=true ;;
        *)            echo "Unknown option: $arg"; echo "Run '$(basename "$0") --help' for usage."; exit 1 ;;
    esac
done

if [ "$NO_COLOR" = true ] || [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    BOLD=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    NC='\033[0m'
fi

TOTAL_RECLAIMABLE=0

header() {
    echo ""
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get directory size in bytes (macOS compatible)
dir_size_bytes() {
    local path="$1"
    if [ -d "$path" ] || [ -f "$path" ]; then
        du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}' || echo 0
    else
        echo 0
    fi
}

# Human-readable size
human_size() {
    local bytes=$1
    if [ "$bytes" -ge 1073741824 ]; then
        echo "$(echo "scale=2; $bytes / 1073741824" | bc) GB"
    elif [ "$bytes" -ge 1048576 ]; then
        echo "$(echo "scale=1; $bytes / 1048576" | bc) MB"
    elif [ "$bytes" -ge 1024 ]; then
        echo "$(echo "scale=0; $bytes / 1024" | bc) KB"
    else
        echo "$bytes B"
    fi
}

# Report a finding
report() {
    local label="$1"
    local path="$2"
    local size_bytes="$3"
    local safety="$4"  # SAFE, CAUTION, REVIEW
    local note="$5"

    if [ "$size_bytes" -le 1048576 ]; then
        return  # Skip anything under 1MB
    fi

    local size_hr
    size_hr=$(human_size "$size_bytes")

    case "$safety" in
        SAFE)     color=$GREEN; icon="✅" ;;
        CAUTION)  color=$YELLOW; icon="⚠️ " ;;
        REVIEW)   color=$CYAN; icon="🔍" ;;
        *)        color=$NC; icon="  " ;;
    esac

    printf "  ${icon} ${color}%-42s %10s${NC}  [%s]\n" "$label" "$size_hr" "$safety"
    if [ -n "$note" ]; then
        echo -e "     ${NC}↳ $note${NC}"
    fi
    echo "     Path: $path"

    if [ "$safety" = "SAFE" ]; then
        TOTAL_RECLAIMABLE=$((TOTAL_RECLAIMABLE + size_bytes))
    fi
}

# Scan a single directory
scan_dir() {
    local label="$1"
    local path="$2"
    local safety="$3"
    local note="$4"
    local size
    size=$(dir_size_bytes "$path")
    report "$label" "$path" "$size" "$safety" "$note"
}

echo ""
echo -e "${BOLD}🔎 macOS System Data Storage Audit${NC}"
echo -e "   Running as: $(whoami) | Date: $(date '+%Y-%m-%d %H:%M')"
echo -e "   ${YELLOW}Note: Some directories may need 'sudo' for accurate sizing${NC}"

# =========================================================================
header "🐳 DOCKER"
# =========================================================================
scan_dir "Docker disk image (all data)" \
    "$HOME/Library/Containers/com.docker.docker/Data" \
    "REVIEW" \
    "Contains all images, containers, volumes. Use 'docker system prune -a' to clean"

scan_dir "Docker Desktop VM" \
    "$HOME/Library/Containers/com.docker.docker/Data/vms" \
    "REVIEW" \
    "VM disk grows over time. 'docker system df' shows breakdown"

# =========================================================================
header "📦 PACKAGE MANAGERS & LANGUAGE CACHES"
# =========================================================================
scan_dir "Homebrew cache" \
    "$HOME/Library/Caches/Homebrew" \
    "SAFE" \
    "Old downloads. Clean: brew cleanup --prune=all"

scan_dir "Homebrew cellar" \
    "/usr/local/Cellar" \
    "REVIEW" \
    "Installed packages. Check for unused: brew autoremove"

# Also check ARM Mac location
scan_dir "Homebrew cellar (ARM)" \
    "/opt/homebrew/Cellar" \
    "REVIEW" \
    "Installed packages (Apple Silicon). Check: brew autoremove"

scan_dir "npm cache" \
    "$HOME/.npm" \
    "SAFE" \
    "Clean: npm cache clean --force"

scan_dir "Yarn cache" \
    "$HOME/Library/Caches/Yarn" \
    "SAFE" \
    "Clean: yarn cache clean"

scan_dir "Yarn cache (v2)" \
    "$HOME/.yarn/cache" \
    "SAFE" \
    "Clean: yarn cache clean"

scan_dir "pnpm store" \
    "$HOME/Library/pnpm/store" \
    "SAFE" \
    "Clean: pnpm store prune"

scan_dir "pip cache" \
    "$HOME/Library/Caches/pip" \
    "SAFE" \
    "Clean: pip cache purge"

scan_dir "pip cache (alt)" \
    "$HOME/.cache/pip" \
    "SAFE" \
    "Clean: pip cache purge"

scan_dir "Maven local repo (.m2)" \
    "$HOME/.m2/repository" \
    "CAUTION" \
    "Java deps. Safe to delete but will re-download on next build"

scan_dir "Gradle caches" \
    "$HOME/.gradle/caches" \
    "SAFE" \
    "Build caches. Clean: gradle --stop && rm -rf ~/.gradle/caches"

scan_dir "Gradle wrapper dists" \
    "$HOME/.gradle/wrapper/dists" \
    "SAFE" \
    "Downloaded Gradle versions"

scan_dir "Go module cache" \
    "$HOME/go/pkg/mod" \
    "SAFE" \
    "Clean: go clean -modcache"

scan_dir "Go build cache" \
    "$HOME/Library/Caches/go-build" \
    "SAFE" \
    "Clean: go clean -cache"

scan_dir "Cargo registry (Rust)" \
    "$HOME/.cargo/registry" \
    "SAFE" \
    "Rust crate cache. Clean: cargo cache -a (needs cargo-cache)"

scan_dir "Cargo build cache" \
    "$HOME/.cargo/git" \
    "SAFE" \
    "Git checkouts for crates"

scan_dir "CocoaPods cache" \
    "$HOME/Library/Caches/CocoaPods" \
    "SAFE" \
    "Clean: pod cache clean --all"

scan_dir "Pub cache (Dart/Flutter)" \
    "$HOME/.pub-cache" \
    "SAFE" \
    "Dart packages"

# =========================================================================
header "🛠️  IDE & DEVELOPER TOOLS"
# =========================================================================
scan_dir "Xcode DerivedData" \
    "$HOME/Library/Developer/Xcode/DerivedData" \
    "SAFE" \
    "Build artifacts. Rebuilds automatically. Safe to delete entirely"

scan_dir "Xcode Archives" \
    "$HOME/Library/Developer/Xcode/Archives" \
    "CAUTION" \
    "Old app builds. Review before deleting"

scan_dir "Xcode device support" \
    "$HOME/Library/Developer/Xcode/iOS DeviceSupport" \
    "SAFE" \
    "Symbols for old iOS versions. Delete old ones"

scan_dir "Xcode watchOS device support" \
    "$HOME/Library/Developer/Xcode/watchOS DeviceSupport" \
    "SAFE" \
    "watchOS debug symbols"

scan_dir "CoreSimulator devices" \
    "$HOME/Library/Developer/CoreSimulator/Devices" \
    "SAFE" \
    "iOS simulators. Clean: xcrun simctl delete unavailable"

scan_dir "CoreSimulator caches" \
    "$HOME/Library/Developer/CoreSimulator/Caches" \
    "SAFE" \
    "Simulator caches"

scan_dir "Android SDK" \
    "$HOME/Library/Android/sdk" \
    "REVIEW" \
    "Check for old platform versions & system images"

scan_dir "Android AVD (emulators)" \
    "$HOME/.android/avd" \
    "REVIEW" \
    "Virtual device images. Delete unused emulators"

scan_dir "IntelliJ / IDEA caches" \
    "$HOME/Library/Caches/JetBrains" \
    "SAFE" \
    "IDE caches, will regenerate"

scan_dir "IntelliJ / IDEA logs" \
    "$HOME/Library/Logs/JetBrains" \
    "SAFE" \
    "IDE log files"

scan_dir "VS Code extensions" \
    "$HOME/.vscode/extensions" \
    "REVIEW" \
    "Check for unused extensions"

scan_dir "VS Code cache" \
    "$HOME/Library/Application Support/Code/Cache" \
    "SAFE" \
    "VS Code cache data"

scan_dir "VS Code CachedData" \
    "$HOME/Library/Application Support/Code/CachedData" \
    "SAFE" \
    "VS Code cached data"

# =========================================================================
header "☁️  CLOUD & VIRTUAL MACHINES"
# =========================================================================
scan_dir "Google Cloud SDK" \
    "$HOME/.config/gcloud" \
    "REVIEW" \
    "GCP config & cached credentials"

scan_dir "Firebase emulator cache" \
    "$HOME/.cache/firebase" \
    "SAFE" \
    "Downloaded emulator JARs"

scan_dir "Terraform plugin cache" \
    "$HOME/.terraform.d/plugin-cache" \
    "SAFE" \
    "Cached provider plugins"

scan_dir "Minikube" \
    "$HOME/.minikube" \
    "REVIEW" \
    "Local K8s cluster data. Delete if not using"

scan_dir "Vagrant boxes" \
    "$HOME/.vagrant.d/boxes" \
    "REVIEW" \
    "VM images. Delete unused boxes"

# =========================================================================
header "🗂️  SYSTEM & APPLICATION CACHES"
# =========================================================================
scan_dir "User cache directory" \
    "$HOME/Library/Caches" \
    "CAUTION" \
    "Total app caches. Individual apps can be cleaned selectively"

scan_dir "User logs" \
    "$HOME/Library/Logs" \
    "SAFE" \
    "Application log files"

scan_dir "Spotlight index" \
    "/System/Volumes/Data/.Spotlight-V100" \
    "REVIEW" \
    "Rebuilt automatically. sudo mdutil -E / to reindex"

scan_dir "Time Machine local snapshots" \
    "/Volumes/com.apple.TimeMachine.localsnapshots" \
    "REVIEW" \
    "List: tmutil listlocalsnapshots / | Delete old ones"

scan_dir "macOS software updates" \
    "/Library/Updates" \
    "SAFE" \
    "Pending/completed update files"

scan_dir "System logs" \
    "/private/var/log" \
    "CAUTION" \
    "System logs. sudo log erase --all (nuclear option)"

scan_dir "Sleepimage" \
    "/private/var/vm/sleepimage" \
    "REVIEW" \
    "Hibernate file, equals RAM size. Recreated on sleep"

scan_dir "Swap files" \
    "/private/var/vm" \
    "REVIEW" \
    "VM swap files, managed by macOS"

# =========================================================================
header "🗑️  TRASH & MISC"
# =========================================================================
scan_dir "User Trash" \
    "$HOME/.Trash" \
    "SAFE" \
    "Empty Trash from Finder"

scan_dir "Node modules (home dir only)" \
    "$HOME/node_modules" \
    "SAFE" \
    "Accidental global node_modules in home dir"

# =========================================================================
header "📊 LARGE node_modules SCAN"
echo -e "  ${YELLOW}Scanning for node_modules directories (top 10 by size)...${NC}"
echo -e "  ${YELLOW}This may take a minute...${NC}"
# =========================================================================

if command -v find &>/dev/null; then
    NM_RESULTS=$(find "$HOME" -name "node_modules" -type d -maxdepth 6 -not -path "*/\.*" 2>/dev/null | head -30)
    NM_TOTAL=0
    declare -a NM_ENTRIES=()

    while IFS= read -r nm_path; do
        [ -z "$nm_path" ] && continue
        nm_size=$(dir_size_bytes "$nm_path")
        if [ "$nm_size" -gt 52428800 ]; then  # > 50MB
            NM_ENTRIES+=("$nm_size|$nm_path")
            NM_TOTAL=$((NM_TOTAL + nm_size))
        fi
    done <<< "$NM_RESULTS"

    # Sort and show top 10
    if [ ${#NM_ENTRIES[@]} -gt 0 ]; then
        printf '%s\n' "${NM_ENTRIES[@]}" | sort -t'|' -k1 -rn | head -10 | while IFS='|' read -r size path; do
            hr=$(human_size "$size")
            printf "  📁 %-50s %10s\n" "$path" "$hr"
        done
        echo ""
        echo -e "  ${BOLD}Total node_modules found: $(human_size $NM_TOTAL)${NC}"
        echo -e "  ${GREEN}Tip: Use 'npx npkill' to interactively delete node_modules${NC}"
    else
        echo -e "  No large node_modules directories found."
    fi
fi

# =========================================================================
header "📊 LARGE build/target DIRECTORY SCAN"
echo -e "  ${YELLOW}Scanning for build artifact directories...${NC}"
# =========================================================================

BUILD_TOTAL=0
declare -a BUILD_ENTRIES=()

for pattern in "target" "build" "dist" ".next" ".nuxt" "__pycache__"; do
    RESULTS=$(find "$HOME" -name "$pattern" -type d -maxdepth 5 \
        -not -path "*/node_modules/*" \
        -not -path "*/\.*" \
        -not -path "*/Library/*" \
        2>/dev/null | head -20)

    while IFS= read -r build_path; do
        [ -z "$build_path" ] && continue
        b_size=$(dir_size_bytes "$build_path")
        if [ "$b_size" -gt 52428800 ]; then  # > 50MB
            BUILD_ENTRIES+=("$b_size|$build_path")
            BUILD_TOTAL=$((BUILD_TOTAL + b_size))
        fi
    done <<< "$RESULTS"
done

if [ ${#BUILD_ENTRIES[@]} -gt 0 ]; then
    printf '%s\n' "${BUILD_ENTRIES[@]}" | sort -t'|' -k1 -rn | head -10 | while IFS='|' read -r size path; do
        hr=$(human_size "$size")
        printf "  📁 %-50s %10s\n" "$path" "$hr"
    done
    echo ""
    echo -e "  ${BOLD}Total build artifacts found: $(human_size $BUILD_TOTAL)${NC}"
fi

# =========================================================================
header "📊 SUMMARY"
# =========================================================================
echo ""
echo -e "  ${GREEN}${BOLD}Estimated safely reclaimable space: $(human_size $TOTAL_RECLAIMABLE)${NC}"
echo -e "  ${YELLOW}(Items marked SAFE only — REVIEW and CAUTION items may add significantly more)${NC}"
echo ""
echo -e "  ${BOLD}Quick wins — copy & paste these commands:${NC}"
echo ""
echo -e "  ${CYAN}# Docker cleanup (can reclaim tens of GBs)${NC}"
echo "  docker system prune -a --volumes"
echo ""
echo -e "  ${CYAN}# Homebrew cleanup${NC}"
echo "  brew cleanup --prune=all && brew autoremove"
echo ""
echo -e "  ${CYAN}# npm/Yarn/pnpm cache${NC}"
echo "  npm cache clean --force"
echo "  yarn cache clean"
echo "  pnpm store prune"
echo ""
echo -e "  ${CYAN}# Java build caches${NC}"
echo "  rm -rf ~/.gradle/caches ~/.gradle/wrapper/dists"
echo "  # rm -rf ~/.m2/repository  # (will re-download deps)"
echo ""
echo -e "  ${CYAN}# Go caches${NC}"
echo "  go clean -cache -modcache"
echo ""
echo -e "  ${CYAN}# Xcode cleanup${NC}"
echo "  rm -rf ~/Library/Developer/Xcode/DerivedData"
echo "  xcrun simctl delete unavailable"
echo ""
echo -e "  ${CYAN}# iOS/watchOS device support (old versions)${NC}"
echo "  # Review: ls ~/Library/Developer/Xcode/iOS\ DeviceSupport/"
echo ""
echo -e "  ${CYAN}# JetBrains IDE caches${NC}"
echo "  rm -rf ~/Library/Caches/JetBrains ~/Library/Logs/JetBrains"
echo ""
echo -e "  ${CYAN}# Interactive node_modules cleanup${NC}"
echo "  npx npkill"
echo ""
echo -e "  ${CYAN}# Empty Trash${NC}"
echo "  rm -rf ~/.Trash/*"
echo ""
echo -e "  ${CYAN}# Firebase emulator cache${NC}"
echo "  rm -rf ~/.cache/firebase"
echo ""
echo -e "${BOLD}${YELLOW}⚠️  Always verify before deleting! This script provides estimates.${NC}"
echo -e "${BOLD}${YELLOW}   Run with 'sudo' for more accurate system directory sizing.${NC}"
echo ""
