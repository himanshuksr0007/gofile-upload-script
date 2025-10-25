#!/bin/bash

# Gofile.io Upload Script
# Just a simple script to upload files to gofile.io
# Works on most systems (hopefully)

set -euo pipefail  # trust issues with bash


# Figure out what OS we're running on
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"  
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    elif grep -q "Microsoft" /proc/version 2>/dev/null; then
        echo "wsl"
    else
        echo "unknown"
    fi
}

OS_TYPE=$(detect_os)

# Colors - because why not make it pretty
if [[ "$OS_TYPE" == "windows" && -z "${TERM:-}" ]]; then
    # Windows CMD doesn't like colors
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
fi

# Global vars
API_TOKEN=""
FOLDER_ID=""
FILE_PATH=""
SERVER_REGION="auto"  # auto should work fine


# Show help text
show_help() {
    cat << EOF
${BLUE}Gofile.io Upload Script${NC}

${YELLOW}Usage:${NC}
    bash gofile_upload.sh [OPTIONS] <file_path>
    
${YELLOW}Platforms:${NC}
    Linux, macOS, Windows (Git Bash/WSL)

${YELLOW}Options:${NC}
    -t, --token TOKEN       API token (optional)
    -f, --folder FOLDER_ID  Folder to upload to (needs token)
    -r, --region REGION     Server region (auto, eu, na, ap-sgp, ap-hkg, ap-tyo, sa)
    -h, --help              Show this help

${YELLOW}Examples:${NC}
    # Simple upload
    bash gofile_upload.sh myfile.pdf

    # With token
    bash gofile_upload.sh --token YOUR_TOKEN myfile.pdf

    # To specific folder
    bash gofile_upload.sh --token YOUR_TOKEN --folder FOLDER_ID myfile.pdf

${YELLOW}Get API Token:${NC}
    Go to https://gofile.io/myProfile and grab your token

${YELLOW}Notes:${NC}
    - Guest uploads work fine
    - Folder upload needs a token
    - First upload gives you a folder ID for later use

EOF
    exit 0
}

# Error and exit
die() {
    echo -e "${RED}ERROR:${NC} $1" >&2
    exit 1
}

# Success message
ok() {
    echo -e "${GREEN}✓${NC} $1"
}

# Info message  
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Warning
warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if we have curl and jq
check_deps() {
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        case "$OS_TYPE" in
            windows)
                die "Missing: ${missing[*]}\n\nFor Windows:\n1. Install Git for Windows\n2. Get jq from https://stedolan.github.io/jq/download/\n3. Add to PATH\n\nOr just use WSL"
                ;;
            macos)
                die "Missing: ${missing[*]}\n\nInstall with: brew install ${missing[*]}"
                ;;
            *)
                die "Missing: ${missing[*]}\n\nInstall with your package manager"
                ;;
        esac
    fi
}

# Get the right upload server
get_server() {
    local region="$1"
    
    case "$region" in
        auto)
            echo "https://upload.gofile.io/uploadfile"
            ;;
        eu)
            echo "https://upload-eu-par.gofile.io/uploadfile"
            ;;
        na)  
            echo "https://upload-na-phx.gofile.io/uploadfile"
            ;;
        ap-sgp)
            echo "https://upload-ap-sgp.gofile.io/uploadfile"
            ;;
        ap-hkg)
            echo "https://upload-ap-hkg.gofile.io/uploadfile"
            ;;
        ap-tyo)
            echo "https://upload-ap-tyo.gofile.io/uploadfile"
            ;;
        sa)
            echo "https://upload-sa-sao.gofile.io/uploadfile"
            ;;
        *)
            warn "Unknown region '$region', using auto"
            echo "https://upload.gofile.io/uploadfile"
            ;;
    esac
}

# Get file size - cross platform stuff
file_size() {
    local file="$1"
    local size
    
    # Different stat commands for different OS
    if [[ "$OS_TYPE" == "macos" || "$OS_TYPE" == "windows" ]]; then
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    else
        size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    fi
    
    # Convert to MB if big enough
    local mb=$((size / 1024 / 1024))
    if [ $mb -gt 0 ]; then
        echo "${mb} MB"
    else
        echo "$((size / 1024)) KB"
    fi
}

# Parse command line args
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t|--token)
                API_TOKEN="$2"
                shift 2
                ;;
            -f|--folder)
                FOLDER_ID="$2"
                shift 2
                ;;
            -r|--region)
                SERVER_REGION="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            -*)
                die "Unknown option: $1\nUse -h for help"
                ;;
            *)
                FILE_PATH="$1"
                shift
                ;;
        esac
    done
}

# Fix Windows paths
fix_path() {
    local path="$1"
    
    # Windows uses backslashes, we need forward slashes
    if [[ "$OS_TYPE" == "windows" || "$OS_TYPE" == "wsl" ]]; then
        path=$(echo "$path" | sed 's/\\/\//g')
    fi
    
    echo "$path"
}

# Check inputs make sense
validate_inputs() {
    if [[ -z "$FILE_PATH" ]]; then
        die "No file specified!\nUse -h for help"
    fi
    
    FILE_PATH=$(fix_path "$FILE_PATH")
    
    # Basic file checks
    if [[ ! -f "$FILE_PATH" ]]; then
        die "File not found: $FILE_PATH"
    fi
    
    if [[ ! -r "$FILE_PATH" ]]; then
        die "Can't read file: $FILE_PATH"
    fi
    
    # Folder needs token
    if [[ -n "$FOLDER_ID" && -z "$API_TOKEN" ]]; then
        die "Folder upload needs API token (use --token)"
    fi
    
    # Show file size - just for fun
    local size=$(file_size "$FILE_PATH")
    info "File size: $size"
}

# Do the actual upload
do_upload() {
    local server=$(get_server "$SERVER_REGION")
    local filename=$(basename "$FILE_PATH")
    
    info "Server: $server"
    info "Uploading: $filename"
    
    # Build curl command
    local cmd=("curl" "-#" "-F" "file=@$FILE_PATH")
    
    # Add auth if we have it
    if [[ -n "$API_TOKEN" ]]; then
        cmd+=("-H" "Authorization: Bearer $API_TOKEN")
        info "Using authentication"
    else
        info "Guest upload"
    fi
    
    # Add folder if specified
    if [[ -n "$FOLDER_ID" ]]; then
        cmd+=("-F" "folderId=$FOLDER_ID")
        info "Target folder: $FOLDER_ID"
    fi
    
    cmd+=("$server")
    
    # Upload and get response
    local response
    if ! response=$("${cmd[@]}" 2>&1); then
        die "Upload failed - check your connection"
    fi
    
    # Parse JSON response
    local status=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "error")
    
    if [[ "$status" != "ok" ]]; then
        local err=$(echo "$response" | jq -r '.status' 2>/dev/null || echo "Unknown error")
        die "Upload failed: $err"
    fi
    
    # Get the good stuff from response
    local page=$(echo "$response" | jq -r '.data.downloadPage // empty')
    local fid=$(echo "$response" | jq -r '.data.fileId // empty')  
    local folder=$(echo "$response" | jq -r '.data.parentFolder // empty')
    local name=$(echo "$response" | jq -r '.data.fileName // empty')
    local hash=$(echo "$response" | jq -r '.data.md5 // empty')
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    # Show results
    echo ""
    echo "════════════════════════════════════════════════════════"
    ok "Upload done!"
    echo "════════════════════════════════════════════════════════"
    echo ""
    
    [[ -n "$page" ]] && echo -e "${GREEN}Download:${NC} $page"
    [[ -n "$name" ]] && echo -e "${BLUE}Filename:${NC} $name"  
    [[ -n "$fid" ]] && echo -e "${BLUE}File ID:${NC}  $fid"
    
    if [[ -n "$folder" ]]; then
        echo -e "${BLUE}Folder:${NC}   $folder"
        echo ""
        info "Save this folder ID for future uploads: --folder $folder"
    fi
    
    [[ -n "$hash" ]] && echo -e "${BLUE}MD5:${NC}      $hash"
    echo -e "${BLUE}Time:${NC}     $timestamp"
    echo ""
}


# Main function
main() {
    # Show what we detected
    case "$OS_TYPE" in
        linux)   info "Detected: Linux" ;;
        macos)   info "Detected: macOS" ;;  
        windows) info "Detected: Windows" ;;
        wsl)     info "Detected: WSL" ;;
        *)       warn "Unknown OS, hoping for the best" ;;
    esac
    
    check_deps
    parse_args "$@"
    validate_inputs  
    do_upload
}

# Let's go!
main "$@"