#!/usr/bin/env python3
"""
Soberano Live Wallpaper High-Resolution Thumbnail & Preview Synthesizer
Generates crystal-clear 16:9 640x360 TrueColor RGB preview frames for all
Steam Workshop Wallpaper Engine items, replacing pixelated 256-color palette GIFs.
"""

import os
import glob
import subprocess
from PIL import Image, ImageEnhance, ImageStat

def main():
    ws = os.path.expanduser("~/.local/share/Steam/steamapps/workshop/content/431960")
    cache_dir = os.path.expanduser("~/.cache/soberano_thumbnails")
    os.makedirs(cache_dir, exist_ok=True)

    if not os.path.exists(ws):
        return

    items = sorted(glob.glob(os.path.join(ws, "*")))
    for p in items:
        if not os.path.isdir(p):
            continue
        item_id = os.path.basename(p)
        out_path = os.path.join(cache_dir, f"hires_{item_id}.jpg")

        # 1. Check for .mp4 / .webm video files
        vids = [f for f in os.listdir(p) if f.lower().endswith((".mp4", ".webm"))]
        done = False
        if vids:
            vid_p = os.path.join(p, vids[0])
            for t in ["25%", "40%", "60%", "15%"]:
                res = subprocess.run([
                    "ffmpegthumbnailer",
                    "-i", vid_p,
                    "-o", out_path,
                    "-s", "640",
                    "-q", "9",
                    "-t", t
                ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if res.returncode == 0 and os.path.exists(out_path):
                    try:
                        im = Image.open(out_path)
                        stat = ImageStat.Stat(im)
                        if stat.mean and sum(stat.mean[:3]) / 3.0 > 15:
                            done = True
                            break
                    except Exception:
                        pass

        # 2. Check preview.jpg / preview.png / preview.webp
        if not done:
            for cand in ["preview.jpg", "preview.png", "preview.webp"]:
                cand_p = os.path.join(p, cand)
                if os.path.exists(cand_p):
                    try:
                        im = Image.open(cand_p).convert("RGB")
                        im.thumbnail((640, 360), Image.Resampling.LANCZOS)
                        canvas = Image.new("RGB", (640, 360), (18, 19, 26))
                        offset = ((640 - im.size[0]) // 2, (360 - im.size[1]) // 2)
                        canvas.paste(im, offset)
                        canvas.save(out_path, "JPEG", quality=95)
                        done = True
                        break
                    except Exception:
                        pass

        # 3. Process animated GIF with frame selection & 24-bit TrueColor upscale
        if not done:
            gif_p = os.path.join(p, "preview.gif")
            if os.path.exists(gif_p):
                try:
                    gim = Image.open(gif_p)
                    best_frame = None
                    best_score = -1
                    f_idx = 0
                    while True:
                        frame = gim.copy().convert("RGB")
                        stat = ImageStat.Stat(frame)
                        mean_b = sum(stat.mean[:3]) / 3.0
                        var_b = sum(stat.var[:3]) / 3.0
                        score = mean_b * 0.4 + var_b * 0.6
                        if score > best_score:
                            best_score = score
                            best_frame = frame
                        f_idx += 1
                        try:
                            gim.seek(f_idx)
                        except EOFError:
                            break
                    if best_frame:
                        w, h = best_frame.size
                        scaled = best_frame.resize((640, int(640 * (h / w))), Image.Resampling.LANCZOS)
                        if scaled.size[1] > 360:
                            top = (scaled.size[1] - 360) // 2
                            scaled = scaled.crop((0, top, 640, top + 360))
                        elif scaled.size[1] < 360:
                            canvas = Image.new("RGB", (640, 360), (18, 19, 26))
                            top = (360 - scaled.size[1]) // 2
                            canvas.paste(scaled, (0, top))
                            scaled = canvas
                        enhancer = ImageEnhance.Sharpness(scaled)
                        scaled = enhancer.enhance(1.2)
                        scaled.save(out_path, "JPEG", quality=95)
                        done = True
                except Exception:
                    pass

if __name__ == "__main__":
    main()
