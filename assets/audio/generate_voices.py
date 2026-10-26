"""《借光》角色语音 v5 — edge-tts 微软 Neural TTS + Madness 氛围
v4 弃 Minimax（AI 朗读感本质问题），换微软 Neural
小一继续用 DROID 素材（已 OK）
"""
import asyncio, pathlib, wave, struct, math

import edge_tts

SCRIPT_DIR = pathlib.Path(__file__).resolve().parent
VOICES_DIR = SCRIPT_DIR / "voices"
SOURCES_DIR = SCRIPT_DIR / "sources"
VOICES_DIR.mkdir(exist_ok=True)

# 清空旧的神明文件（保留小一的 DROID 那个）
for old in VOICES_DIR.glob("*_deity.wav"):
    old.unlink()

# ---------- edge-tts 生成 ----------
# zh-CN-YunxiNeural = 云希，磁性低沉男声，微软中文男声中最有"神性"的
# rate=-10% 温和偏慢；pitch=-2Hz 极轻微降调（不刻意，不像 Minimax 那样压变形）
# 微软 Neural TTS 是目前免费可用的最自然中文 TTS

DEITY_LINES = [
    ("frame03_deity.wav", "小一……传回来的那片绿，是什么？"),
    ("frame05_deity.wav", "小一……维护系统，在收紧。"),
    ("frame06_deity.wav", "它们要清空……意识区。"),
    ("frame08_deity.wav", "你能……回来吗？"),
]

VOICE = "zh-CN-YunxiNeural"
RATE = "-10%"       # 温和偏慢，不是 Minimax 那种刻意拖
PITCH = "-2Hz"      # 极轻微降调，不刻意
VOLUME = "+10%"     # 略放大一点，后续混音更清晰

async def gen_edge_tts(filename: str, text: str):
    out_path = VOICES_DIR / filename
    print(f"[EDGE] {filename}: {text}")
    communicate = edge_tts.Communicate(
        text=text,
        voice=VOICE,
        rate=RATE,
        pitch=PITCH,
        volume=VOLUME,
    )
    # 先输出到 .mp3，再用 afconvert 转 wav（Mac 自带）
    mp3_path = VOICES_DIR / "_temp.mp3"
    await communicate.save(str(mp3_path))
    # 转码 wav 44100 mono
    import subprocess
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@44100", str(mp3_path), str(out_path)],
        check=True, capture_output=True,
    )
    mp3_path.unlink(missing_ok=True)
    print(f"  OK ({out_path.stat().st_size // 1024} KB)")

async def main():
    print(f"=== edge-tts 生成神明 ({VOICE}) ===")
    for fn, text in DEITY_LINES:
        await gen_edge_tts(fn, text)

asyncio.run(main())

# ---------- 工具 ----------
def wav_info(path):
    with wave.open(str(path), "rb") as wf:
        return wf.getframerate(), wf.getnframes(), wf.getnchannels(), wf.getsampwidth()

def read_wav_float(path):
    sr, nframes, nch, sw = wav_info(path)
    with wave.open(str(path), "rb") as wf:
        raw = wf.readframes(nframes)
    fmt = "h" if sw == 2 else "b"
    total = nframes * nch
    samples_raw = struct.unpack(fmt * total, raw)
    scale = 32768.0 if sw == 2 else 128.0
    if nch == 2:
        samples = [(samples_raw[i] + samples_raw[i+1]) / 2 / scale for i in range(0, total, 2)]
    else:
        samples = [s / scale for s in samples_raw]
    if sr != 44100:
        ratio = 44100.0 / sr
        new_len = int(len(samples) * ratio)
        samples = [samples[min(int(i / ratio), len(samples) - 1)] for i in range(new_len)]
    return samples

def write_wav_float(path, samples, sr=44100):
    peak = max(abs(s) for s in samples) if samples else 1.0
    peak = peak or 1.0
    with wave.open(str(path), "wb") as wf:
        wf.setparams((1, 2, sr, 0, "NONE", "not compressed"))
        wf.writeframes(b"".join(
            struct.pack("<h", max(-32768, min(32767, int(s / peak * 0.95 * 32767))))
            for s in samples
        ))

# ---------- 叠加 Madness 氛围（轻量）----------
print("\n=== 叠加 Madness 氛围 (10%) ===")
ambience_path = SOURCES_DIR / "madness_a5-menacing.wav"

for fn, _ in DEITY_LINES:
    target = VOICES_DIR / fn
    samples = read_wav_float(target)
    amb_full = read_wav_float(ambience_path)
    amb = amb_full * (len(samples) // len(amb_full) + 1)
    amb = amb[:len(samples)]
    # 淡入淡出
    fade = min(len(samples) // 5, 22050)
    for i in range(fade):
        k = i / fade
        amb[i] *= k
        amb[-(i+1)] *= k
    # 混合：人声 90% + 氛围 10%
    mixed = [samples[i] * 0.92 + amb[i] * 0.08 for i in range(len(samples))]
    write_wav_float(target, mixed)
    print(f"  MIX OK: {fn}")

print("\nDone. Voices in:", VOICES_DIR)
