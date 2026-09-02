from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path('/home/ubuntu/upload/grok_1788365881417.jpg')
ASSET_DIR = ROOT / 'assets' / 'icons'
ANDROID_RES = ROOT / 'android' / 'app' / 'src' / 'main' / 'res'

ASSET_DIR.mkdir(parents=True, exist_ok=True)
im = Image.open(SOURCE).convert('RGB').resize((1024, 1024), Image.Resampling.LANCZOS)
pixels = []
for r, g, b in im.getdata():
    luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
    alpha = int(max(0.0, min(1.0, (145.0 - luminance) / 110.0)) * 255)
    pixels.append((0, 0, 0, alpha))
mark = Image.new('RGBA', im.size)
mark.putdata(pixels)
mark.save(ASSET_DIR / 'rumuo_bird_transparent.png')

for size, name in [(48, 'rumuo_notification.png'), (1024, 'rumuo_launcher.png')]:
    scaled = mark.resize((size, size), Image.Resampling.LANCZOS)
    target = ANDROID_RES / 'drawable' / name if size == 48 else ASSET_DIR / name
    target.parent.mkdir(parents=True, exist_ok=True)
    scaled.save(target)

for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    scaled = mark.resize((size, size), Image.Resampling.LANCZOS)
    for name in ('ic_launcher.png', 'ic_launcher_round.png', 'ic_launcher_foreground.png'):
        out = ANDROID_RES / f'mipmap-{density}' / name
        out.parent.mkdir(parents=True, exist_ok=True)
        scaled.save(out)

for size, name in [(192, 'Icon-192.png'), (512, 'Icon-512.png'), (192, 'Icon-maskable-192.png'), (512, 'Icon-maskable-512.png')]:
    scaled = mark.resize((size, size), Image.Resampling.LANCZOS)
    scaled.save(ROOT / 'web' / 'icons' / name)
mark.resize((192, 192), Image.Resampling.LANCZOS).save(ROOT / 'web' / 'favicon.png')
print('Prepared transparent Rumuo bird assets.')
