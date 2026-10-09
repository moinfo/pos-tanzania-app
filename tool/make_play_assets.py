"""Builds the Google Play graphics for Kariakoo Shops into kariakoo_play_assets/.

    python tool/make_play_assets.py

Inputs : kariakoo_images/kariakoo-logo.png         (1024 px app icon, rounded corners)
         kariakoo_images/WhatsApp Image *.jpeg      (576x1280 phone screenshots)
Outputs: app-icon-512.png               512x512   full-bleed icon
         feature-graphic-1024x500.png   1024x500  banner: two phones + app name
         phone-screenshots/01..11.png   1080x1920 designs: headline + TWO phones each
         tablet-7-inch/01..08.png       1920x1080 landscape (16:9) designs inside a tablet frame
         tablet-10-inch/01..08.png      2560x1440 landscape (16:9), same designs for the 10-inch slot
         desktop-screenshots/01..08.png 2560x1440 website screenshots on a monitor (Desktop slot)
"""
import glob
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
SRC = os.path.join(ROOT, 'kariakoo_images')
OUT = os.path.join(ROOT, 'kariakoo_play_assets')
os.makedirs(os.path.join(OUT, 'phone-screenshots'), exist_ok=True)

GREEN = (27, 140, 48)
GREEN_DARK = (10, 107, 26)
GREEN_LIGHT = (33, 160, 56)
FONT_B = 'C:/Windows/Fonts/segoeuib.ttf'
FONT_R = 'C:/Windows/Fonts/segoeui.ttf'

# (headline, sub-headline, left screen, right screen) -- indices into the
# alphabetically sorted "WhatsApp Image *.jpeg" list.
DESIGNS = [
    ('Browse & order', 'The whole catalogue in your pocket', 5, 3),
    ('Secure by design', 'Password or fingerprint sign-in and a safe log out', 2, 22),
    ('Run your whole shop', 'Sales, stock, suppliers, banking and more', 6, 17),
    ('Your day at a glance', 'Live dashboard for sales, expenses and profit', 19, 20),
    ('Reports & summaries', 'Sales, items, customers, stock and charts', 18, 14),
    ('Expenses & cash', 'Record expenses, profit and cash submissions', 13, 8),
    ('Daily summary', 'Pick any day and see every figure', 10, 9),
    ('English & Kiswahili', 'Switch language and theme any time', 12, 16),
    # --- second set: screens the first set did not use ---------------------
    ('Auto sign-out protection', 'A countdown warns you before you are logged out', 0, 23),
    ('Dark mode & Kiswahili', 'Comfortable in any light, in your language', 11, 15),
    ('Everything in one menu', 'Customers, items, sales, suppliers and banking', 21, 24),
]

# Screens captured before the green redesign: this blue is recoloured to the
# green the app now shows, so the store art matches the build users install.
RECOLOUR_BLUE = {23}


def font(path, size):
    return ImageFont.truetype(path, size)


def gradient(size, c1, c2, diagonal=True):
    """Gradient from c1 (top-left) to c2 (bottom-right)."""
    w, h = size
    g = Image.linear_gradient('L').resize((w, h))
    if diagonal:
        gh = Image.linear_gradient('L').rotate(90).resize((w, h))
        g = Image.blend(g, gh, 0.5)
    return Image.composite(Image.new('RGB', size, c2), Image.new('RGB', size, c1), g)


def recolour_blue_to_green(im):
    """Old blue buttons (about #1565C0) -> the app's current brand green."""
    im = im.convert('RGB')
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if b > 140 and r < 70 and g < 140 and b - r > 90:      # strong blue
                t = min(1.0, (b - 120) / 100.0)
                px[x, y] = (int(27 * t + r * (1 - t)), int(140 * t + g * (1 - t)), int(48 * t + b * (1 - t)))
    return im


def load_screen(files, i):
    im = Image.open(files[i])
    return recolour_blue_to_green(im) if i in RECOLOUR_BLUE else im


def screens():
    return sorted(glob.glob(os.path.join(SRC, 'WhatsApp*.jpeg')))


# ---------------------------------------------------------------- app icon
def make_icon():
    logo = Image.open(os.path.join(SRC, 'kariakoo-logo.png')).convert('RGBA')
    w, h = logo.size
    # Rounded, transparent corners -> full-bleed square in the logo's own green.
    tl, tr = logo.getpixel((260, 2))[:3], logo.getpixel((w - 260, 2))[:3]
    bl, br = logo.getpixel((260, h - 3))[:3], logo.getpixel((w - 260, h - 3))[:3]
    top = gradient((w, h), tl, tr, diagonal=False).rotate(90)
    bottom = gradient((w, h), bl, br, diagonal=False).rotate(90)
    bg = Image.composite(bottom, top, Image.linear_gradient('L').resize((w, h)))
    base = Image.alpha_composite(bg.convert('RGBA'), logo).convert('RGB')
    base.save(os.path.join(OUT, 'icon_1024_full_bleed.png'))
    icon = base.resize((512, 512), Image.LANCZOS)
    icon.save(os.path.join(OUT, 'app-icon-512.png'), optimize=True)
    return icon


# --------------------------------------------------------- phone mockup
def fit_2to1(im):
    """Crop the Android bars so a tall shot is at most 2:1."""
    w, h = im.size
    if h <= w * 2:
        return im
    extra = h - w * 2
    top = int(extra * 0.40)
    return im.crop((0, top, w, top + w * 2))


def phone(screen, width, tilt=0):
    """Phone frame (rounded bezel + camera dot) around a screenshot; RGBA."""
    bez = max(6, width // 22)
    r_out = width // 7
    sw = width - 2 * bez
    sh = int(sw * 2.0)
    scr = fit_2to1(screen.convert('RGB')).resize((sw, sh), Image.LANCZOS)
    h = sh + 2 * bez
    body = Image.new('RGBA', (width, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, width - 1, h - 1), r_out, fill=(18, 22, 20, 255))
    d.rounded_rectangle((2, 2, width - 3, h - 3), r_out - 2, outline=(70, 78, 74, 255), width=2)
    mask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, sw - 1, sh - 1), r_out - bez, fill=255)
    body.paste(scr, (bez, bez), mask)
    if tilt:
        body = body.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return body


def place(canvas, layer, x, y, blur=16, alpha=130, dy=10):
    """Paste [layer] with a soft drop shadow (padded so the blur is not clipped)."""
    pad = blur * 3
    a = Image.new('L', (layer.width + 2 * pad, layer.height + 2 * pad), 0)
    a.paste(layer.getchannel('A').point(lambda v: v * alpha // 255), (pad, pad))
    a = a.filter(ImageFilter.GaussianBlur(blur))
    sh = Image.new('RGBA', a.size, (0, 0, 0, 0))
    sh.putalpha(a)
    canvas.alpha_composite(sh, (x - pad, y - pad + dy)) if (x - pad >= 0 and y - pad + dy >= 0 and
        x - pad + sh.width <= canvas.width and y - pad + dy + sh.height <= canvas.height) else         canvas.paste(sh, (x - pad, y - pad + dy), sh)
    canvas.alpha_composite(layer, (x, y)) if (x >= 0 and y >= 0 and x + layer.width <= canvas.width
        and y + layer.height <= canvas.height) else canvas.paste(layer, (x, y), layer)


def logo_tile(icon, size):
    """The app icon as a rounded tile with a white ring."""
    ring = max(4, size // 18)
    inner = size - 2 * ring
    tile = icon.resize((inner, inner), Image.LANCZOS)
    m = Image.new('L', (inner, inner), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, inner - 1, inner - 1), inner // 4, fill=255)
    out = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle((0, 0, size - 1, size - 1), size // 4 + 2, fill=(255, 255, 255, 255))
    out.paste(tile, (ring, ring), m)
    return out


def discs(canvas, specs):
    layer = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for box, a in specs:
        d.ellipse(box, fill=(255, 255, 255, a))
    canvas.alpha_composite(layer)


# ------------------------------------------------- store screenshot designs
def make_designs(files, icon):
    W, H = 1080, 1920
    paths = []
    for n, (title, sub, li, ri) in enumerate(DESIGNS, 1):
        bg = gradient((W, H), GREEN_LIGHT, GREEN_DARK).convert('RGBA')
        discs(bg, [((600, -260, 1240, 380), 22), ((-300, 1500, 360, 2160), 18)])
        d = ImageDraw.Draw(bg)
        tf = font(FONT_B, 92 if len(title) < 20 else (80 if len(title) < 23 else 72))
        tw = d.textlength(title, font=tf)
        d.text(((W - tw) / 2, 92), title, font=tf, fill='white')
        sf = font(FONT_R, 40)
        sw_ = d.textlength(sub, font=sf)
        d.text(((W - sw_) / 2, 214), sub, font=sf, fill=(226, 247, 230))

        left = phone(load_screen(files, li), 540, tilt=4)
        right = phone(load_screen(files, ri), 580, tilt=-3)
        place(bg, left, 12, 520, blur=22, alpha=150, dy=16)
        place(bg, right, W - right.width - 8, 380, blur=22, alpha=150, dy=16)

        # brand footer: logo tile + name, centred
        d = ImageDraw.Draw(bg)
        fb = font(FONT_B, 44)
        label = 'Kariakoo Shops'
        tile = logo_tile(icon, 120)
        total = tile.width + 24 + d.textlength(label, font=fb)
        x0 = int((W - total) / 2)
        place(bg, tile, x0, H - 168, blur=8, alpha=110, dy=5)
        d.text((x0 + tile.width + 24, H - 168 + 28), label, font=fb, fill='white')
        p = os.path.join(OUT, 'phone-screenshots', '%02d.png' % n)
        bg.convert('RGB').save(p, optimize=True)
        paths.append(p)
    return paths


def tablet(screens_, width, tilt=0, wide=False):
    """A landscape 7-inch tablet (rounded bezel, camera dot) whose display shows
    the app screens side by side on a soft background; RGBA."""
    bez = max(10, width // 34)
    r_out = width // 22
    sw = width - 2 * bez
    sh = int(sw * 0.625)                      # 16:10 display
    h = sh + 2 * bez
    body = Image.new('RGBA', (width, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    d.rounded_rectangle((0, 0, width - 1, h - 1), r_out, fill=(18, 22, 20, 255))
    d.rounded_rectangle((3, 3, width - 4, h - 4), r_out - 3, outline=(70, 78, 74, 255), width=3)

    # display: pale green wash + the two app screens as cards
    disp = gradient((sw, sh), (236, 247, 239), (205, 232, 212)).convert('RGBA')
    if wide:
        # one wide (desktop) screenshot, shown whole across the display
        im = screens_[0].convert('RGB')
        scale = min(sw / im.width, sh / im.height)
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
        disp.paste(im, ((sw - im.width) // 2, (sh - im.height) // 2))
        screens_ = []
    card_h = int(sh * 0.90)
    card_w = card_h // 2
    gap = int(sw * 0.045)
    total = 2 * card_w + gap
    x0 = (sw - total) // 2
    y0 = (sh - card_h) // 2
    for k, im in enumerate(screens_):
        shot = fit_2to1(im.convert('RGB')).resize((card_w, card_h), Image.LANCZOS)
        m = Image.new('L', (card_w, card_h), 0)
        ImageDraw.Draw(m).rounded_rectangle((0, 0, card_w - 1, card_h - 1), card_w // 12, fill=255)
        card = Image.new('RGBA', (card_w, card_h), (0, 0, 0, 0))
        card.paste(shot, (0, 0), m)
        place(disp, card, x0 + k * (card_w + gap), y0, blur=10, alpha=90, dy=6)
    dmask = Image.new('L', (sw, sh), 0)
    ImageDraw.Draw(dmask).rounded_rectangle((0, 0, sw - 1, sh - 1), r_out - bez, fill=255)
    body.paste(disp, (bez, bez), dmask)
    d = ImageDraw.Draw(body)
    cy = h // 2
    d.ellipse((bez // 2 - 4, cy - 4, bez // 2 + 4, cy + 4), fill=(60, 66, 63, 255))   # camera
    if tilt:
        body = body.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return body


# ------------------------------------------------ tablet (landscape) designs
# The eight designs of the upload set, as indices into DESIGNS.
TABLET_PICK = [0, 3, 10, 4, 8, 5, 6, 9]


def make_tablet(files, icon, folder, size=(1920, 1080)):
    """16:9 landscape designs: headline + logo on the left, two phones right."""
    W, H = size
    k = W / 1920.0
    os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    for old in glob.glob(os.path.join(OUT, folder, '*.png')):
        os.remove(old)
    for n, idx in enumerate(TABLET_PICK, 1):
        title, sub, li, ri = DESIGNS[idx]
        bg = gradient((W, H), GREEN_LIGHT, GREEN_DARK).convert('RGBA')
        discs(bg, [((int(1100 * k), int(-380 * k), int(1900 * k), int(420 * k)), 22),
                   ((int(-260 * k), int(700 * k), int(420 * k), int(1380 * k)), 18)])
        d = ImageDraw.Draw(bg)

        # logo + name, top left
        tile = logo_tile(icon, int(150 * k))
        place(bg, tile, int(110 * k), int(110 * k), blur=10, alpha=110, dy=6)
        d.text((int(290 * k), int(150 * k)), 'Kariakoo Shops', font=font(FONT_B, int(56 * k)), fill='white')

        # headline (wrapped to the left column)
        tf = font(FONT_B, int(88 * k))
        words, lines, cur = title.split(), [], ''
        for w_ in words:
            t = (cur + ' ' + w_).strip()
            if d.textlength(t, font=tf) > 640 * k and cur:
                lines.append(cur)
                cur = w_
            else:
                cur = t
        lines.append(cur)
        y = int(380 * k)
        for ln in lines:
            d.text((int(110 * k), y), ln, font=tf, fill='white')
            y += int(100 * k)
        sf = font(FONT_R, int(36 * k))
        words, cur, sl = sub.split(), '', []
        for w_ in words:
            t = (cur + ' ' + w_).strip()
            if d.textlength(t, font=sf) > 600 * k and cur:
                sl.append(cur)
                cur = w_
            else:
                cur = t
        sl.append(cur)
        y += int(24 * k)
        for ln in sl:
            d.text((int(112 * k), y), ln, font=sf, fill=(226, 247, 230))
            y += int(50 * k)

        # the tablet on the right, showing both screens
        tab = tablet([load_screen(files, li), load_screen(files, ri)], int(1060 * k), tilt=0)
        place(bg, tab, int(780 * k + (W - 780 * k - tab.width) / 2), int((H - tab.height) / 2),
              blur=26, alpha=150, dy=18)

        bg.convert('RGB').save(os.path.join(OUT, folder, '%02d.png' % n), optimize=True)


def monitor(shot, width):
    """A desktop monitor (thin bezel, neck and base) showing [shot]; RGBA."""
    bez = max(10, width // 70)
    sw = width - 2 * bez
    sh = int(sw * 0.5625)                       # 16:9 display
    top_h = sh + 2 * bez
    neck_h = int(width * 0.075)
    base_h = int(width * 0.022)
    total_h = top_h + neck_h + base_h
    body = Image.new('RGBA', (width, total_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(body)
    r = width // 60
    d.rounded_rectangle((0, 0, width - 1, top_h - 1), r, fill=(28, 32, 31, 255))
    d.rounded_rectangle((3, 3, width - 4, top_h - 4), r - 3, outline=(80, 88, 84, 255), width=2)
    disp = Image.new('RGB', (sw, sh), (255, 255, 255))
    im = shot.convert('RGB')
    scale = min(sw / im.width, sh / im.height)
    im = im.resize((int(im.width * scale), int(im.height * scale)), Image.LANCZOS)
    disp.paste(im, ((sw - im.width) // 2, (sh - im.height) // 2))
    body.paste(disp, (bez, bez))
    # neck + base
    nx0, nx1 = int(width * 0.455), int(width * 0.545)
    d.rectangle((nx0, top_h - 1, nx1, top_h + neck_h), fill=(58, 64, 61, 255))
    d.rounded_rectangle((int(width * 0.34), top_h + neck_h - 2, int(width * 0.66), total_h - 1),
                        base_h // 2, fill=(40, 45, 43, 255))
    return body


def make_desktop(icon, folder, size=(2560, 1440)):
    """Desktop-slot designs: the website screenshots on a monitor."""
    W, H = size
    k = W / 1920.0
    os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    for old in glob.glob(os.path.join(OUT, folder, '*.png')):
        os.remove(old)
    for n, (frag, title, sub) in enumerate(DESKTOP, 1):
        src = glob.glob(os.path.join(SRC, 'desktop', '*%s*.png' % frag))[0]
        bg = gradient((W, H), GREEN_LIGHT, GREEN_DARK).convert('RGBA')
        discs(bg, [((int(1100 * k), int(-380 * k), int(1900 * k), int(420 * k)), 22),
                   ((int(-260 * k), int(700 * k), int(420 * k), int(1380 * k)), 18)])
        d = ImageDraw.Draw(bg)
        tile = logo_tile(icon, int(150 * k))
        place(bg, tile, int(110 * k), int(110 * k), blur=10, alpha=110, dy=6)
        d.text((int(290 * k), int(150 * k)), 'Kariakoo Shops', font=font(FONT_B, int(56 * k)), fill='white')

        def wrap(text, f, maxw):
            out, cur = [], ''
            for w_ in text.split():
                t = (cur + ' ' + w_).strip()
                if d.textlength(t, font=f) > maxw and cur:
                    out.append(cur)
                    cur = w_
                else:
                    cur = t
            out.append(cur)
            return out

        tf = font(FONT_B, int(80 * k))
        y = int(380 * k)
        for ln in wrap(title, tf, 560 * k):
            d.text((int(110 * k), y), ln, font=tf, fill='white')
            y += int(92 * k)
        sf = font(FONT_R, int(36 * k))
        y += int(22 * k)
        for ln in wrap(sub, sf, 560 * k):
            d.text((int(112 * k), y), ln, font=sf, fill=(226, 247, 230))
            y += int(50 * k)

        mon = monitor(Image.open(src), int(1180 * k))
        place(bg, mon, int(700 * k + (W - 700 * k - mon.width) / 2), int((H - mon.height) / 2),
              blur=26, alpha=150, dy=18)
        bg.convert('RGB').save(os.path.join(OUT, folder, '%02d.png' % n), optimize=True)


# ---------------------------------- tablet designs from the desktop screenshots
DESKTOP = [
    # (file name fragment, headline, sub-headline)
    ('154815', 'Sign in to manage your store', 'The same login on web and mobile'),
    ('154930', 'Every module in one place', 'Customers, items, sales, receivings and more'),
    ('155026', 'Reports at your fingertips', 'Graphical, summary, detailed and inventory reports'),
    ('155100', 'Track supplier credit', 'Daily credit, debit and balances by supplier'),
    ('155152', 'A fast sales register', 'Scan or search items and take payment'),
    ('155242', 'Cash submissions', 'Daily cash, bank and sales figures in one table'),
    ('155325', 'Receive stock', 'Record deliveries and keep stock in step'),
    ('155615', 'Transfers between stores', 'Move stock between locations with a few taps'),
]


def make_tablet_desktop(icon, folder, size):
    """Tablet frames showing the website's desktop screenshots."""
    W, H = size
    k = W / 1920.0
    os.makedirs(os.path.join(OUT, folder), exist_ok=True)
    for old in glob.glob(os.path.join(OUT, folder, '*.png')):
        os.remove(old)
    for n, (frag, title, sub) in enumerate(DESKTOP, 1):
        src = glob.glob(os.path.join(SRC, 'desktop', '*%s*.png' % frag))[0]
        bg = gradient((W, H), GREEN_LIGHT, GREEN_DARK).convert('RGBA')
        discs(bg, [((int(1100 * k), int(-380 * k), int(1900 * k), int(420 * k)), 22),
                   ((int(-260 * k), int(700 * k), int(420 * k), int(1380 * k)), 18)])
        d = ImageDraw.Draw(bg)
        tile = logo_tile(icon, int(150 * k))
        place(bg, tile, int(110 * k), int(110 * k), blur=10, alpha=110, dy=6)
        d.text((int(290 * k), int(150 * k)), 'Kariakoo Shops', font=font(FONT_B, int(56 * k)), fill='white')

        def wrap(text, f, maxw):
            out, cur = [], ''
            for w_ in text.split():
                t = (cur + ' ' + w_).strip()
                if d.textlength(t, font=f) > maxw and cur:
                    out.append(cur)
                    cur = w_
                else:
                    cur = t
            out.append(cur)
            return out

        tf = font(FONT_B, int(80 * k))
        y = int(380 * k)
        for ln in wrap(title, tf, 600 * k):
            d.text((int(110 * k), y), ln, font=tf, fill='white')
            y += int(92 * k)
        sf = font(FONT_R, int(36 * k))
        y += int(22 * k)
        for ln in wrap(sub, sf, 600 * k):
            d.text((int(112 * k), y), ln, font=sf, fill=(226, 247, 230))
            y += int(50 * k)

        tab = tablet([Image.open(src)], int(1060 * k), wide=True)
        place(bg, tab, int(780 * k + (W - 780 * k - tab.width) / 2), int((H - tab.height) / 2),
              blur=26, alpha=150, dy=18)
        bg.convert('RGB').save(os.path.join(OUT, folder, '%02d.png' % n), optimize=True)


# ----------------------------------------------------- feature graphic
def make_feature(icon, files):
    W, H = 1024, 500
    bg = gradient((W, H), GREEN_LIGHT, GREEN_DARK).convert('RGBA')
    discs(bg, [((640, -170, 1100, 290), 22), ((-110, 330, 190, 630), 18)])

    tile = icon.resize((112, 112), Image.LANCZOS)
    m = Image.new('L', tile.size, 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, 111, 111), 26, fill=255)
    ring = Image.new('RGBA', (124, 124), (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle((0, 0, 123, 123), 31, fill=(255, 255, 255, 255))
    ring.paste(tile, (6, 6), m)
    place(bg, ring, 60, 74, blur=10, alpha=120, dy=6)

    d = ImageDraw.Draw(bg)
    d.text((60, 214), 'Kariakoo Shops', font=font(FONT_B, 54), fill='white')
    d.text((62, 282), 'Your Marketplace Destination', font=font(FONT_R, 26), fill=(226, 247, 230))
    cf = font(FONT_B, 20)
    y = 340
    for row in (['Sales & POS', 'Stock'], ['Customers', 'Reports']):
        x = 62
        for c in row:
            tw = d.textlength(c, font=cf)
            d.rounded_rectangle((x, y, x + tw + 28, y + 38), 19, fill=(255, 255, 255))
            d.text((x + 14, y + 4), c, font=cf, fill=GREEN_DARK)
            x += int(tw) + 40
        y += 48
    d.text((62, 448), 'English  \u2022  Kiswahili', font=font(FONT_R, 21), fill=(226, 247, 230))

    # two phones: the shop page and the staff dashboard
    for img, pw, tilt, cx, top in ((Image.open(files[19]), 205, -6, 640, 54),
                                   (Image.open(files[5]), 225, 5, 858, 26)):
        ph = phone(img, pw, tilt)
        place(bg, ph, cx - ph.width // 2, top, blur=16, alpha=140, dy=10)

    out = bg.convert('RGB')
    out.save(os.path.join(OUT, 'feature-graphic-1024x500.png'), optimize=True)
    return out


if __name__ == '__main__':
    for old in glob.glob(os.path.join(OUT, 'phone-screenshots', '*.png')):
        os.remove(old)
    icon = make_icon()
    files = screens()
    make_designs(files, icon)
    make_tablet(files, icon, 'tablet-7-inch')
    make_tablet(files, icon, 'tablet-10-inch', size=(2560, 1440))
    make_tablet_desktop(icon, 'tablet-7-inch-desktop', (1920, 1080))
    make_tablet_desktop(icon, 'tablet-10-inch-desktop', (2560, 1440))
    make_desktop(icon, 'desktop-screenshots')
    make_feature(icon, files)
    for f in sorted(glob.glob(os.path.join(OUT, '**', '*.png'), recursive=True)):
        im = Image.open(f)
        print('%-40s %5s KB  %dx%d' % (os.path.relpath(f, OUT), os.path.getsize(f) // 1024, *im.size))
