#!/bin/bash

set -euo pipefail

#===============================================================================
# Detect Operating System
#===============================================================================
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

#===============================================================================
# Color codes
#===============================================================================
if [[ "$OS_TYPE" == "windows" && -z "${TERM:-}" ]]; then
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

#===============================================================================
# Configuration
#===============================================================================
API_TOKEN=""
FOLDER_ID=""
FILE_PATH=""
SERVER_REGION="auto"
DEBUG_MODE="false"

#===============================================================================
# Functions
#===============================================================================

show_usage() {
    cat << 'EOF'
Gofile.io Upload Script

Usage:
    bash gofile_upload.sh [OPTIONS] <file_path>

Options:
    -t, --token TOKEN       Your Gofile.io API token (optional for guest)
    -f, --folder FOLDER_ID  Upload to specific folder (requires token)
    -r, --region REGION     Server region: auto, eu, na, ap-sgp, ap-hkg, ap-tyo, sa
    -d, --debug             Enable debug mode (verbose output)
    -h, --help              Show this help message

Examples:
    bash gofile_upload.sh myfile.pdf
    bash gofile_upload.sh --token TOKEN myfile.pdf
    bash gofile_upload.sh -d myfile.pdf

EOF
    exit 0
}

error_exit() {
    echo -e "${RED}ERROR:${NC} $1" >&2
    exit 1
}

success_msg() {
    echo -e "${GREEN}✓${NC} $1"
}

info_msg() {
    echo -e "${BLUE}ℹ${NC} $1"
}

warn_msg() {
    echo -e "${YELLOW}⚠${NC} $1"
}

debug_msg() {
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "${YELLOW}[DEBUG]${NC} $1" >&2
    fi
}

check_dependencies() {
    local missing=()
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: Missing:${NC} ${missing[*]}"
        echo ""
        if [[ "$OS_TYPE" == "wsl" || "$OS_TYPE" == "linux" ]]; then
            echo "Install with:"
            echo "  sudo apt update && sudo apt install -y ${missing[*]}"
        elif [[ "$OS_TYPE" == "macos" ]]; then
            echo "Install with Homebrew:"
            echo "  brew install ${missing[*]}"
        fi
        echo ""
        error_exit "Please install missing dependencies"
    fi
}

get_upload_server() {
    case "$1" in
        auto)  echo "https://upload.gofile.io/uploadfile" ;;
        eu)    echo "https://upload-eu-par.gofile.io/uploadfile" ;;
        na)    echo "https://upload-na-phx.gofile.io/uploadfile" ;;
        ap-sgp) echo "https://upload-ap-sgp.gofile.io/uploadfile" ;;
        ap-hkg) echo "https://upload-ap-hkg.gofile.io/uploadfile" ;;
        ap-tyo) echo "https://upload-ap-tyo.gofile.io/uploadfile" ;;
        sa)    echo "https://upload-sa-sao.gofile.io/uploadfile" ;;
        *)     warn_msg "Unknown region, using auto"; echo "https://upload.gofile.io/uploadfile" ;;
    esac
}

get_file_size() {
    local size
    if [[ "$OS_TYPE" == "macos" ]]; then
        size=$(stat -f%z "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null)
    else
        size=$(stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null)
    fi
    
    local mb=$((size / 1024 / 1024))
    if [ $mb -gt 0 ]; then
        echo "${mb} MB"
    else
        echo "$((size / 1024)) KB"
    fi
}

parse_arguments() {
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
            -d|--debug)
                DEBUG_MODE="true"
                shift
                ;;
            -h|--help)
                show_usage
                ;;
            -*)
                error_exit "Unknown option: $1"
                ;;
            *)
                FILE_PATH="$1"
                shift
                ;;
        esac
    done
}

validate_inputs() {
    if [[ -z "$FILE_PATH" ]]; then
        error_exit "No file specified!"
    fi
    
    if [[ ! -f "$FILE_PATH" ]]; then
        error_exit "File not found: $FILE_PATH"
    fi
    
    if [[ ! -r "$FILE_PATH" ]]; then
        error_exit "File is not readable: $FILE_PATH"
    fi
    
    if [[ -n "$FOLDER_ID" && -z "$API_TOKEN" ]]; then
        error_exit "Folder ID requires an API token (use --token)"
    fi
    
    local size
    size=$(get_file_size "$FILE_PATH")
    info_msg "File size: $size"
}
    copy_to_clipboard() {
    local text="$1"
    [[ -z "$text" ]] && return

    case "$OS_TYPE" in
        macos) echo -n "$text" | pbcopy ;;
        windows|wsl) echo -n "$text" | clip.exe ;;
        linux)
            if command -v xclip &>/dev/null; then
                echo -n "$text" | xclip -selection clipboard
            elif command -v wl-copy &>/dev/null; then
                echo -n "$text" | wl-copy
            fi
            ;;
    esac
    info_msg "Link copied to clipboard!"
}
upload_file() {

    local upload_url
    upload_url=$(get_upload_server "$SERVER_REGION")
    
    info_msg "Server: $upload_url"
    info_msg "Uploading: $(basename "$FILE_PATH")"
    
    # Create temporary files for stderr and stdout
    local tmp_stderr tmp_stdout
    tmp_stderr=$(mktemp)
    tmp_stdout=$(mktemp)
    
    trap "rm -f $tmp_stderr $tmp_stdout" EXIT
    
    local curl_args=("-w" "\n%{http_code}")

    curl_args+=(
        "--connect-timeout" "10"
        "--retry" "3"
        "--retry-delay" "2"
    )
    
    if [[ "$DEBUG_MODE" == "true" ]]; then
        info_msg "Debug mode ENABLED - verbose curl output to follow"
        curl_args+=("-s")
        curl_args+=("-v")
    else
        curl_args+=("-#") 
    fi
    
    curl_args+=("-F" "file=@$FILE_PATH")
    
    if [[ -n "$API_TOKEN" ]]; then
        curl_args+=("-H" "Authorization: Bearer $API_TOKEN")
        info_msg "Authenticated upload"
    else
        info_msg "Guest upload"
    fi
    
    if [[ -n "$FOLDER_ID" ]]; then
        curl_args+=("-F" "folderId=$FOLDER_ID")
        debug_msg "Folder ID: $FOLDER_ID"
    fi
    
    curl_args+=("$upload_url")
    
    debug_msg "Curl command: curl ${curl_args[*]}"
    echo ""
    
    if [[ "$DEBUG_MODE" == "true" ]]; then

        curl "${curl_args[@]}" 2>"$tmp_stderr" >"$tmp_stdout"

        cat "$tmp_stderr" >&2
        echo ""
    else

        curl "${curl_args[@]}" >"$tmp_stdout"
    fi
    
    # Read response
    local response
    response=$(cat "$tmp_stdout")
    
    debug_msg "Raw stdout response: $response"
    
    # Extract HTTP code (last line)
    local http_code
    http_code=$(echo "$response" | tail -n1)
    
    # Remove HTTP code line from response
    response=$(echo "$response" | head -n-1)
    
    debug_msg "HTTP Status Code: $http_code"
    debug_msg "Response body: $response"
    
    # Validate HTTP code
    if ! [[ "$http_code" =~ ^[0-9]{3}$ ]]; then
        error_exit "Failed to get valid HTTP response code: '$http_code'\n\nResponse:\n$response"
    fi
    
    if [[ "$http_code" != "200" ]]; then
        error_exit "Server returned HTTP $http_code\n\nResponse:\n$response"
    fi
    
    # Validate JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        error_exit "Invalid JSON response from server:\n$response\n\nPlease check your connection or try again"
    fi
    
    # Check API status
    local status
    status=$(echo "$response" | jq -r '.status // "error"' 2>/dev/null)
    
    debug_msg "API Status: $status"
    
    if [[ "$status" != "ok" ]]; then
        local api_error
        api_error=$(echo "$response" | jq -r '.error // .status // "Unknown error"' 2>/dev/null)
        debug_msg "Full response: $response"
        error_exit "API Error: $api_error\n\nFull response:\n$response"
    fi
    
    # Extract data
    local download_page file_id parent_folder file_name md5 upload_time
    
    download_page=$(echo "$response" | jq -r '.data.downloadPage // empty' 2>/dev/null)
    file_id=$(echo "$response" | jq -r '.data.fileId // empty' 2>/dev/null)
    parent_folder=$(echo "$response" | jq -r '.data.parentFolder // empty' 2>/dev/null)
    file_name=$(echo "$response" | jq -r '.data.fileName // empty' 2>/dev/null)
    md5=$(echo "$response" | jq -r '.data.md5 // empty' 2>/dev/null)
    upload_time=$(date '+%Y-%m-%d %H:%M:%S %Z')
    
    debug_msg "Extraction successful - Download: $download_page"
    
    # Display results
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    success_msg "Upload completed successfully!"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    
    [[ -n "$download_page" ]] && echo -e "${GREEN}Download Page:${NC} $download_page"
    [[ -n "$file_name" ]] && echo -e "${BLUE}File Name:${NC}     $file_name"
    [[ -n "$file_id" ]] && echo -e "${BLUE}File ID:${NC}       $file_id"
    
    if [[ -n "$parent_folder" ]]; then
        echo -e "${BLUE}Folder ID:${NC}     $parent_folder"
        echo ""
        info_msg "Use this for future uploads: --folder $parent_folder"
    fi
    
    [[ -n "$md5" ]] && echo -e "${BLUE}MD5 Hash:${NC}      $md5"
    echo -e "${BLUE}Upload Time:${NC}   $upload_time"
    echo ""

  
    copy_to_clipboard "$download_page"
}

#===============================================================================
# Main
#===============================================================================

main() {
    case "$OS_TYPE" in
        linux) info_msg "Detected: Linux" ;;
        macos) info_msg "Detected: macOS" ;;
        windows) info_msg "Detected: Windows" ;;
        wsl) info_msg "Detected: WSL" ;;
        *) warn_msg "Unknown OS" ;;
    esac
    
    check_dependencies
    parse_arguments "$@"
    
    [[ "$DEBUG_MODE" == "true" ]] && info_msg "Debug mode ENABLED"
    
    validate_inputs
    upload_file
}

main "$@"
