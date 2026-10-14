"""English laid over images whose Japanese is part of a larger picture.

GameDocuments/OverlayText.md gives the English (the ```text block after each
item). The original image stays (base = true^); its Japanese is painted out
(erase) and the English set in its place (blocks). Used by build_en_text.py.

- System messages (205 x 37): everything under the underline is cleared and
  the English set there, white with a dark edge.
- Story intro pictures (640 x 480): the body text's box (found from its dark
  pixels, widened to the English if that is wider) is painted white and the
  English set in black, wrapped, at the largest size that fits.
- The pause screen's instructions (system 0165): too dense to paint over, so
  an English picture made for it (PAUSE_ENGLISH) is shown instead.
"""
import re
from PIL import Image, ImageFont

BOLD = 'data/montserrat/Montserrat-Bold.ttf'
PAUSE = 'assets/system/ヴァンガードプリンセス/images/0165.png'

PAUSE_ENGLISH = 'data/images/Instraction.png'


def sections(root, doc):
    """Each item of the document: (image path or None, English lines), in order."""
    lines = (root / doc).read_text(encoding='utf-8').split('\n')
    out = []
    path = None
    section = ''
    i = 0
    while i < len(lines):
        line = lines[i]
        if line.startswith('## '):
            section = line[3:]
        m = re.search(r'(assets.(?:shared|characters|system).+\.png)$', line)
        if m:
            path = m.group(1).replace('\\', '/')
        if line.startswith('```text'):
            j = i + 1
            body = []
            while not lines[j].startswith('```'):
                body.append(lines[j])
                j += 1
            out.append((section, path, body))
            path = None
            i = j
        i += 1
    return out


def lton_string(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"') + '"'


def colour(c):
    return '{ ' + ', '.join(f'{v:.3f}'.rstrip('0').rstrip('.') if isinstance(v, float) else str(v) for v in c) + ' }'


def lines_lton(body, indent='            '):
    return ''.join(f'{indent}{{ text = {lton_string(l if l.strip() else " ")} }},\n' for l in body)


def system_message(root, path, body):
    im = Image.open(root / path).convert('RGBA')
    w, h = im.size
    px = im.load()
    # The underline: the topmost row opaque nearly all the way across (a row
    # of the outlined Japanese can be dense too, but never this dense).
    rule = min(y for y in range(h) if sum(1 for x in range(w) if px[x, y][3] > 200) > w * 0.85)
    top = rule + 2
    # The Japanese's left edge, below the underline's own dark border.
    lefts = [x for y in range(top + 2, h) for x in range(w) if px[x, y][3] > 100]
    left = min(lefts) if lefts else 8
    return (f'["{path}"] = {{\n'
            f'    base = true^, size = {{ {w}, {h} }},\n'
            f'    erase = {{ {{ 0, {top}, {w}, {h - top}, color = {{ 0, 0, 0, 0 }} }} }},\n'
            f'    blocks = {{\n        {{\n'
            f'            lines = {{\n{lines_lton(body, "                ")}            }},\n'
            f'            rect = {{ {left}, {top}, {w - left - 2}, {h - top} }}, align = "left", valign = "middle",\n'
            f'        }},\n    }},\n'
            f'    font = "{BOLD}", fontSize = 11, weight = 2,\n'
            f'    color = {{ 1, 1, 1 }}, outline = {{ color = {{ 0, 0, 0 }}, width = 1 }},\n'
            f'}},\n')


def wrap(font, body, width):
    out = []
    for line in body:
        if not line.strip():
            out.append('')
            continue
        current = ''
        for word in line.split(' '):
            trial = (current + ' ' + word).strip()
            if current and font.getlength(trial) > width:
                out.append(current)
                current = word
            else:
                current = trial
        out.append(current)
    return out


def intro(root, path, body):
    im = Image.open(root / path).convert('RGBA')
    px = im.load()
    # The body text: rows of dark pixels starting near the left, each row's
    # run followed rightwards while gaps stay short (the picture is further).
    rows = {}
    for y in range(88, 360):
        x = 20
        right = None
        while x < 420:
            r, g, b, a = px[x, y]
            if a > 200 and r + g + b < 200:
                if right is None and x > 60:
                    break
                right = x
            elif right is not None and x - right > 24:
                break
            x += 1
        if right is not None:
            rows[y] = right
    top, bottom = min(rows), max(rows)
    left, right = 24, max(rows.values()) + 2
    width = max(right - left, 360)
    height = bottom - top
    for size in range(15, 9, -1):
        font = ImageFont.truetype(str(root / BOLD), size)
        wrapped = wrap(font, body, width - 8)
        line_h = font.getbbox('Ag')[3] + 4
        leading = max(2, min(12, (height - len(wrapped) * line_h) // max(len(wrapped) - 1, 1)))
        if len(wrapped) * line_h + (len(wrapped) - 1) * 2 <= height + 16:
            break
    widest = max(font.getlength(l) for l in wrapped)
    box_w = max(right - left, round(widest) + 10)
    box = (left - 6, top - 8, box_w + 14, height + 18)
    return (f'["{path}"] = {{\n'
            f'    base = true^, size = {{ 640, 480 }},\n'
            f'    erase = {{ {{ {box[0]}, {box[1]}, {box[2]}, {box[3]}, color = {{ 1, 1, 1, 1 }} }} }},\n'
            f'    blocks = {{\n        {{\n'
            f'            lines = {{\n{lines_lton(body, "                ")}            }},\n'
            f'            wrap = true^, rect = {{ {left}, {top - 4}, {box_w}, {height + 10} }}, align = "left", valign = "middle",\n'
            f'        }},\n    }},\n'
            f'    leading = {leading}, font = "{BOLD}", fontSize = {size},\n'
            f'    color = {{ 0, 0, 0 }},\n'
            f'}},\n')


def pause(root):
    return f'["{PAUSE}"] = {{ base = "{PAUSE_ENGLISH}", size = {{ 640, 480 }} }},\n'


def overlay_entries(root):
    items = sections(root, 'GameDocuments/OverlayText.md')
    out = []
    for section, path, body in items:
        if section.startswith('システムメッセージ') and path:
            out.append(system_message(root, path, body))
        elif section.startswith('ストーリー冒頭') and path:
            out.append(intro(root, path, body))
    out.append(pause(root))
    return out
