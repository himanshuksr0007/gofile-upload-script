# Gofile.io Upload Script

A bash script for uploading files to [Gofile.io](https://gofile.io) with or without their API.
Works on Windows, macOS, and Linux. (hopefully)

## Features

- **Guest Uploads** - Just upload without needing an account
- **Authenticated Uploads** - Use API keys, if you want to
- **Folder Management** - Upload to specific folders
- **Progress Display** - See upload progress as it happens
- **Detailed Output** - Get download link, file ID, folder ID, MD5 hash, and timestamp
- **Error Handling** - Detailed error logs if something went wrong
- **Batch Uploads** - Reuse folder IDs to keep related files together
- **Cross-Platform** - Works on Windows via Git Bash/WSL, macOS, and Linux

## Platform Support

| Platform | Status | Method |
|----------|--------|--------|
| **Linux** | ✅ Works | Native bash |
| **macOS** | ✅ Works | Native bash (both Intel & M1/M2) |
| **Windows** | ✅ Works | Git Bash or WSL |

## Requirements

You need these installed:

1. **curl** - for making HTTP requests
2. **jq** - for parsing JSON
3. **bash** - should already be there

### Installation

#### Linux & macOS
```bash
git clone https://github.com/himanshuksr0007/gofile-upload-script.git
cd gofile-upload-script
chmod +x gofile_upload.sh
```

Optionally, throw it in your PATH:
```bash
sudo cp gofile_upload.sh /usr/local/bin/gofile
```

#### Windows (Git Bash)
```bash
git clone https://github.com/himanshuksr0007/gofile-upload-script.git
cd gofile-upload-script
```

Already executable in Git Bash. Add to PATH if you want it globally available.

#### Windows (WSL)
Same as Linux instructions above.

## Usage

### Basic Command

**Linux/macOS:**
```bash
./gofile_upload.sh [OPTIONS] <file_path>
```

**Windows (Git Bash/WSL):**
```bash
bash gofile_upload.sh [OPTIONS] <file_path>
```

### Options

| Option | What it does |
|--------|-------------|
| `-t, --token TOKEN` | Gofile.io API token (optional) |
| `-f, --folder FOLDER_ID` | Upload to a specific folder (API key required) |
| `-r, --region REGION` | Pick server: `auto`, `eu`, `na`, `ap-sgp`, `ap-hkg`, `ap-tyo`, `sa` (default: auto)|
| `-h, --help` | Shows help |

### Regions

- **auto** - Picks the closest server automatically (default)
- **eu** - Europe (Paris)
- **na** - North America (Phoenix)
- **ap-sgp** - Singapore
- **ap-hkg** - Hong Kong
- **ap-tyo** - Tokyo
- **sa** - São Paulo

## Examples

### Linux & macOS

#### Simple guest upload (no account needed)
```bash
./gofile_upload.sh myfile.pdf

# Upload to EU servers
./gofile_upload.sh --region eu document.zip

# Big video file
./gofile_upload.sh --region na video.mp4
```

#### With authentication
```bash
# Using your API token
./gofile_upload.sh --token API_KEY presentation.pptx

# Upload to specific folder you own
./gofile_upload.sh --token API_KEY --folder abc123 report.pdf
```

#### Batch upload trick
```bash
# First upload (guest is fine)
./gofile_upload.sh file1.pdf
# It returns a Folder ID, something like: xyz123

# Now add more files to the same folder
./gofile_upload.sh --folder xyz123 file2.pdf
./gofile_upload.sh --folder xyz123 file3.pdf
```

#### More examples
```bash
# Token + region
./gofile_upload.sh --token YOUR_TOKEN --region eu backup.tar.gz

# Upload a bunch of JPGs to your folder
for file in *.jpg; do
    ./gofile_upload.sh --token YOUR_TOKEN --folder FOLDER_ID "$file"
done
```

### Windows (Git Bash/WSL)

#### Guest uploads
```bash
bash gofile_upload.sh myfile.pdf
bash gofile_upload.sh --region eu document.zip
```

#### Authenticated
```bash
bash gofile_upload.sh --token API_KEY presentation.pptx
bash gofile_upload.sh --token API_KEY --folder abc123 report.pdf
```

#### Batch (PowerShell)
```powershell
for ($i = 1; $i -le 3; $i++) {
    bash gofile_upload.sh --folder xyz123 "file$i.pdf"
}
```

### Making it easier to use

**Windows (Git Bash) - Create a shortcut:**

Make a file called `gofile.cmd`:
```batch
@echo off
bash.exe "%~dp0gofile_upload.sh" %*
```

Add it to PATH and you're golden.

**macOS/Linux - Alias:**
```bash
echo "alias gofile='bash /path/to/gofile_upload.sh'" >> ~/.bashrc
source ~/.bashrc

# Then just:
gofile myfile.pdf
```

## Getting Your API Token

1. Go to [https://gofile.io/myProfile](https://gofile.io/myProfile)
2. Sign in or make an account (it's free)
3. Copy your API token
4. Use it with `--token`


## What the output looks like

```
ℹ Detected: Linux
ℹ File size: 15 MB
ℹ Server: https://upload.gofile.io/uploadfile
ℹ Uploading: document.pdf
ℹ Guest upload
######################################################################## 100.0%

════════════════════════════════════════════════════════
✓ Upload done!
════════════════════════════════════════════════════════

Download: https://gofile.io/d/aBcDeF
Filename: document.pdf
File ID:  xyz123abc
Folder:   folder456
MD5:      d41d8cd98f00b204e9800998ecf8427e
Time:     2025-10-24 22:35:45 IST

ℹ Save this folder ID for future uploads: --folder folder456
```

## Disclaimer

This is unofficial - not made by or endorsed by Gofile.io. Use at your own risk and all that.

## Thanks to Gofile.io

Thanks to gofile for providing,:
- Fast uploads and downloads
- Generous free service
- No storage limits on free tier
- Files are encrypted and private
- Multiple server locations
- No registration required for guest uploads

If you use it, consider making an account or going premium to support them.

---

## Troubleshooting

### "Missing required dependencies: curl jq"

**Linux:**
```bash
# Ubuntu/Debian
sudo apt install curl jq

# CentOS/RHEL
sudo yum install curl jq
```

**macOS:**
```bash
brew install curl jq
```

**Windows (Git Bash):**
- curl is already in Git Bash
- Get jq from [https://stedolan.github.io/jq/download/](https://stedolan.github.io/jq/download/)
- Add it to PATH

**Windows (WSL):**
```bash
sudo apt update
sudo apt install curl jq
```

### "File not found"
- Check your path
- Use quotes for filenames with spaces: `"my file.pdf"`
- Windows users can use forward slashes: `Documents/myfile.pdf`

### "Upload failed"
- Check internet connection
- Make sure file is readable: `ls -l filename`
- Try different region with `--region`

### "Folder ID requires an API token"
- Can't use `--folder` without a token
- Either drop the `--folder` or add `--token YOUR_TOKEN`

### Windows: "Permission denied"
- Use Git Bash, not regular CMD
- Try `bash gofile_upload.sh` instead of `./gofile_upload.sh`

### macOS: "command not found: jq"
- Install it: `brew install jq`
- Check if it's in PATH: `which jq`

### Still stuck?

1. Check [Issues](https://github.com/himanshuksr0007/gofile-upload-script/issues)
2. Look at [Gofile.io API docs](https://gofile.io/api)
3. Make sure dependencies are installed
4. Open an [issue](https://github.com/himanshuksr0007/gofile-upload-script/issues) with error details and platform info

## Links

- [Gofile.io](https://gofile.io)
- [Gofile.io API](https://gofile.io/api)
- [Report Issues](https://github.com/himanshuksr0007/gofile-upload-script/issues)
- [Git for Windows](https://git-scm.com/download/win)
- [jq Download](https://stedolan.github.io/jq/download/)
- [WSL Installation](https://learn.microsoft.com/en-us/windows/wsl/install)

---


*Please Star this repo if you liked it*