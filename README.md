# jellyfin-converter - grandedata.no

A macOS script that converts MKV files to a Jellyfin-optimized format using HandBrakeCLI. Processes both movies and TV shows automatically with retry logic and ntfy notifications.

---

## How it works

The script does two things:

1. **Movies** — Finds MKV files in movie folders, converts to a new file, verifies the size, deletes the original on success.

2. **TV shows** — Finds MKV episodes recursively, converts to `.tmp.mkv`, replaces the original with `mv` on success, and creates a `.done` marker file to avoid converting twice.

## Features

- Up to 3 automatic retries per file on failure
- Size check — requires a minimum of 100 MB to approve the conversion
- Half-finished files are detected and converted again
- Skips files already converted
- Preserves all audio tracks and subtitles
- Sends ntfy alerts on start, completion, and error

## Requirements

- macOS
- [HandBrakeCLI](https://handbrake.fr/downloads2.php) installed in `/usr/local/bin/`
- `no_burn.json` preset file (see step 3)
- ntfy server

## Installation

### Step 1 — Download HandBrakeCLI

Go to [handbrake.fr/downloads2.php](https://handbrake.fr/downloads2.php) and download HandBrakeCLI for macOS. Extract it and move it to `/usr/local/bin/`:

```bash
sudo mv HandBrakeCLI /usr/local/bin/
chmod +x /usr/local/bin/HandBrakeCLI
```

### Step 2 — Clone the repo

```bash
git clone https://github.com/Kgrande93/jellyfin-converter.git
cd jellyfin-converter
```

### Step 3 — Add the preset file

Copy `no_burn.json` to your desktop, or update the `PRESET_FILE` variable in the script to wherever the file is located.

### Step 4 — Configure the script

Open `convert_movies.sh` and edit the variables at the top:

```bash
HANDBRAKE="/usr/local/bin/HandBrakeCLI"
MOVIES_DIR="/Volumes/jellyfin/Movies"
SHOWS_DIR="/Volumes/jellyfin/Shows"
PRESET_FILE="$HOME/Desktop/no_burn.json"
NTFY_URL="https://ntfy.example.com/yourtopic"
```

### Step 5 — Make the script executable

```bash
chmod +x convert_movies.sh
```

### Step 6 — Run

```bash
./convert_movies.sh
```

## Files

| File                | Description                                                        |
| ------------------- | -------------------------------------------------------------------- |
| `convert_movies.sh` | Main script                                                           |
| `no_burn.json`      | HandBrake preset — preserves audio tracks and subtitles without burn-in |
| `README.md`      | This file |
| `LICENSE`      | LICENSE |

## Logging

The script logs to the terminal and sends ntfy alerts:

- 🎬 When conversion starts
- ✅ When a file is done and the original is deleted/replaced
- ⚠️ On a failed attempt
- ❌ On total failure after all retries
- 🏁 When everything is complete

## Infrastructure

Runs locally on a Mac against the Jellyfin disk mounted via SMB. HandBrakeCLI runs one conversion at a time to save disk space.
