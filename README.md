# Gofile Upload Script

Simple bash script to upload files to [Gofile.io](https://gofile.io).

## Install

```bash
wget -q https://raw.githubusercontent.com/himanshuksr0007/gofile-upload-script/main/go.sh -O ~/gofile && chmod +x ~/gofile
echo 'alias gofile="~/gofile"' >> ~/.bashrc && source ~/.bashrc
```

## Usage

```bash
gofile [OPTIONS] <file>
```

## Options

- `-t, --token TOKEN` - Gofile API token
- `-f, --folder FOLDER_ID` - Upload to a specific folder
- `-r, --region REGION` - Server region: `auto`, `eu`, `na`, `ap-sgp`, `ap-hkg`, `ap-tyo`, `sa`
- `-h, --help` - Show help

## Examples

```bash
gofile myfile.zip
gofile --region eu document.pdf
gofile --token YOUR_TOKEN report.pdf
gofile --token YOUR_TOKEN --folder FOLDER_ID backup.tar.gz
```

## Get API Token

Get your token from [Gofile Profile](https://gofile.io/myProfile).

## Notes

- `--folder` requires a token.
