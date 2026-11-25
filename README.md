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
chapterize ep.mp3 --show "Cozy Zone"   # associate with a show by name
chapterize ep.mp3 --no-open            # stage without opening the app
chapterize ep.mp3 --title "Ep 12" --chapters chapters.txt
                                       # set the title and chapters
pbpaste | chapterize ep.mp3 --chapters - # chapters from stdin
chapterize ep.mp3 --wait               # wait for the import and report what it did
chapterize ep.mp3 --background         # open the app without bringing it forward
chapterize ep.mp3 --dry-run            # check the inputs, change nothing
chapterize --open                      # just open the app
chapterize ep.mp3 --json               # JSON result on stdout
```

Use `--show` to associate the file with a show by name (no IDs). If a show
with that name already exists in Chapterize, the file is loaded pre-associated
with it (name and artwork); if not, the name is still applied as the episode's
show label. The name applies to every file in the command.

Audio can be mp3, m4a, mp4, m4b, wav, wave, aif, or aiff (non-MP3 formats are converted
inside the app, exactly like a drag-and-drop import). A subtitle file sitting
next to the audio with the same name (`ep.mp3` plus `ep.srt` or `ep.vtt`) is
picked up automatically; `--no-auto-subs` turns that off.

Progress goes to stderr and results go to stdout, so it pipes cleanly.

The first run may trigger a macOS prompt asking to allow access to data from
other apps. Approve it: the tool works by handing files to Chapterize's
inbox. If you denied it, re-enable access in System Settings under Privacy
and Security before trying again.

## Scripts and agents

`chapterize` is built to be driven by scripts and AI agents as well as people:

- `--json` prints exactly one JSON object on stdout, on success and on
  failure (even for an unknown flag). Read `ok` first. A success lists each
  file under `staged` (with the inbox `drop` it was handed over in); a
  failure carries `error` with a stable `code`, a `message`, and the
  `exitCode`. Progress and messages go to stderr.
- `--dry-run` validates every input (paths, types, subtitle pairing, show
  name) and reports what would load, without touching the inbox or the app.
- `--background` opens Chapterize without bringing it to the front.
- `--chapters <file>` (or `-` for stdin) takes `TIME - Title` lines
  (`0:00 - Intro`, `1:02:03 Outro`) or Podcasting 2.0 chapters JSON, and
  replaces any chapters the audio already has. It is checked before anything
  is staged, so a bad file fails with `invalid_chapters`. `--title` sets the
  episode title. Both need a single audio file.
- `--wait [--timeout N]` (default 300 seconds per file) waits until the app
  has imported each file and adds its report to the output: `importStatus`
  (`imported`, `failed`, `picked_up`, `pending`) and `result` with the
  document id, title, show (and whether it matched one in the library),
  duration, chapter count and source, transcript lines, whether a
  transcription is running, and warnings. A Chapterize version from before
  receipts (3.0 and earlier) still takes the files, but reports `picked_up`
  with no details.
- `chapterize --help` carries examples and the exit codes below.

```sh
$ chapterize ep.mp3 --show "Comfort Zone" --json
{
  "dryRun" : false,
  "ok" : true,
  "opened" : true,
  "staged" : [
    {
      "audio" : "/Users/me/ep.mp3",
      "drop" : "/Users/me/Library/Group Containers/.../Inbox/6F1C...",
      "show" : "Comfort Zone",
      "subtitles" : "/Users/me/ep.srt"
    }
  ],
  "version" : "1.2.0"
}
```

The tool sends no analytics or usage data (versions before 1.2 sent one
anonymous event per run; that is gone).

## Exit codes

| Code | `error.code` | Meaning |
| --- | --- | --- |
| 0 | | Success |
| 1 | `usage`, `file_not_found`, `unsupported_type`, `invalid_chapters` | Bad input or usage error |
| 2 | `app_not_installed`, `staging_failed`, `open_failed` | Handoff failure |
| 3 | `permission_denied` | macOS blocked access to Chapterize's inbox. A person has to allow it (the "access data from other apps" prompt, or System Settings, Privacy and Security, App Management); retrying will not help |
| 4 | `import_failed` | With `--wait`: the app could not import a file (`result.error` says why) |
| 5 | `timed_out` | With `--wait`: the app did not pick the files up in time; they stay in its inbox and load the next time it runs |
