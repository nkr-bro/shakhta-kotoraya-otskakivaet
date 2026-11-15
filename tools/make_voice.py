"""Russian voice-over for every dialogue line found in scripts/*.gd.

Uses the macOS "Milena" voice; characters differ by pitch. Files are named
by the first 12 hex digits of md5(text), which Sfx.voice() looks up.
"""
import hashlib
import re
import subprocess
import tempfile
from pathlib import Path

OUT = Path("assets/voice")
OUT.mkdir(parents=True, exist_ok=True)
PAIR = re.compile(r'\["([^"]*)", "([^"]*)"\]')


def pitch_for(speaker: str) -> float:
    if speaker.startswith("Шахтёр"):
        return 0.86
    if speaker.startswith("Брат"):
        return 0.76
    if speaker.startswith("Механик") or speaker.startswith("Голос"):
        return 0.68
    return 1.0


lines = {}
for f in sorted(Path("scripts").glob("*.gd")):
    for speaker, text in PAIR.findall(f.read_text()):
        lines[text] = speaker
keep = set()
for text, speaker in lines.items():
    name = hashlib.md5(text.encode("utf-8")).hexdigest()[:12] + ".wav"
    keep.add(name)
    dst = OUT / name
    if dst.exists():
        continue
    k = pitch_for(speaker)
    with tempfile.TemporaryDirectory() as td:
        aiff = Path(td) / "v.aiff"
        subprocess.run(["say", "-v", "Milena", "-r", "180", "-o", str(aiff), text], check=True)
        af = f"asetrate=22050*{k},aresample=22050,atempo={1 / k:.4f}" if k != 1.0 else "aresample=22050"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(aiff), "-af", af + ",volume=1.6",
                        "-ac", "1", "-ar", "22050", "-sample_fmt", "s16", str(dst)], check=True)
for old in OUT.glob("*.wav"):
    if old.name not in keep:
        old.unlink()
print(len(lines), "lines voiced")
