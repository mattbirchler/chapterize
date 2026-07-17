# chapterize

Load audio and subtitle files into the [Chapterize](https://apps.apple.com/app/chapterize)
Mac app from the command line. Point it at an episode (with optional SRT or
VTT subtitles) and it appears in Chapterize as a new document, ready for
chapter editing.

Pairs well with [quicksubs](https://github.com/mattbirchler/quicksubs):
transcribe an episode, then hand the audio and transcript straight to
Chapterize.

## Install

```sh
brew install mattbirchler/tap/chapterize
```

Requires macOS 26 (Tahoe) or later, and Chapterize 1.6 or later.

## Usage

```sh
chapterize episode.mp3                 # load into the app, then open it
chapterize ep.mp3 -s ep.srt            # load with a specific subtitle file
chapterize a.mp3 b.mp3                 # load two documents at once
chapterize ep.mp3 --no-open            # stage without opening the app
chapterize --open                      # just open the app
chapterize ep.mp3 --json -q            # silent run, JSON result on stdout
```

Audio can be mp3, m4a, mp4, m4b, wav, or aiff (non-MP3 formats are converted
inside the app, exactly like a drag-and-drop import). A subtitle file sitting
next to the audio with the same name (`ep.mp3` plus `ep.srt` or `ep.vtt`) is
picked up automatically; `--no-auto-subs` turns that off.

Progress goes to stderr and results go to stdout, so it pipes cleanly.

The first run may trigger a macOS prompt asking to allow access to data from
other apps. Approve it: the tool works by handing files to Chapterize's
inbox.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | Bad input or usage error |
| 2 | Handoff failure (Chapterize not installed, staging or open failed) |
