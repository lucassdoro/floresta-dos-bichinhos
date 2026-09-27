#!/usr/bin/env python3
"""Monta o trailer a partir da gravação do Movie Maker.

Lê as linhas "TRAILER_SEGMENT nome inicio fim" (quadros) do log da gravação,
corta cada trecho do AVI, junta com transições cruzadas e gera um MP4 leve
para a web, mais um pôster em WebP.

Uso: python3 tools/trailer/make_trailer.py gravacao.log gravacao.avi saida.mp4
Requer ffmpeg no PATH. Instruções completas em tools/trailer/README.md.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

FPS = 30
FADE = 0.4
WIDTH, HEIGHT = 1280, 720
SEGMENT = re.compile(r"^TRAILER_SEGMENT (\S+) (\d+) (\d+)$")


def read_segments(log_path):
    segments = []
    for line in Path(log_path).read_text(encoding="utf-8", errors="replace").splitlines():
        match = SEGMENT.match(line.strip())
        if not match:
            continue
        name, start, end = match.group(1), int(match.group(2)), int(match.group(3))
        if end - start < FPS:
            print(f"aviso: trecho '{name}' curto demais, ignorado")
            continue
        segments.append((name, start, end))
    return segments


def build_filter(segments):
    parts = []
    lengths = []
    for index, (_, start, end) in enumerate(segments):
        lengths.append((end - start) / FPS)
        parts.append(
            f"[0:v]trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS,"
            f"scale={WIDTH}:{HEIGHT}:flags=lanczos,fps={FPS},format=yuv420p[v{index}]"
        )
        parts.append(
            f"[0:a]atrim=start={start / FPS:.3f}:end={end / FPS:.3f},asetpts=PTS-STARTPTS[a{index}]"
        )
    video, audio = "v0", "a0"
    elapsed = lengths[0]
    for index in range(1, len(segments)):
        offset = elapsed - FADE
        parts.append(f"[{video}][v{index}]xfade=transition=fade:duration={FADE}:offset={offset:.3f}[x{index}]")
        parts.append(f"[{audio}][a{index}]acrossfade=d={FADE}[y{index}]")
        video, audio = f"x{index}", f"y{index}"
        elapsed = offset + lengths[index]
    parts.append(f"[{video}]fade=t=in:st=0:d=0.5,fade=t=out:st={elapsed - 0.8:.3f}:d=0.8[vout]")
    parts.append(f"[{audio}]afade=t=in:st=0:d=0.5,afade=t=out:st={elapsed - 0.8:.3f}:d=0.8[aout]")
    return ";".join(parts), elapsed


def write_poster(video, at_seconds):
    """Quadro do trailer como pôster: WebP com cwebp, senão JPG."""
    frame = Path(video).with_suffix(".poster.png")
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-ss", f"{at_seconds:.2f}", "-i", video, "-frames:v", "1", str(frame),
    ], check=True)
    if shutil.which("cwebp"):
        poster = Path(video).with_suffix(".webp")
        subprocess.run(["cwebp", "-quiet", "-q", "82", str(frame), "-o", str(poster)], check=True)
    else:
        poster = Path(video).with_suffix(".jpg")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(frame), "-q:v", "4", str(poster)], check=True)
    frame.unlink()
    return poster


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    log_path, avi_path, output = argv
    segments = read_segments(log_path)
    if not segments:
        print("nenhum TRAILER_SEGMENT no log")
        return 1
    graph, duration = build_filter(segments)
    print("trechos:", ", ".join(f"{name} {(end - start) / FPS:.1f}s" for name, start, end in segments))
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-i", avi_path,
        "-filter_complex", graph, "-map", "[vout]", "-map", "[aout]",
        "-c:v", "libx264", "-preset", "slow", "-crf", "24", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "96k", "-movflags", "+faststart", output,
    ], check=True)
    poster = write_poster(output, duration * 0.25)
    print(f"ok: {output} ({duration:.1f}s) e {poster}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
