"""Erzeugt das App-Symbol von Tessa.

Vier Bloecke in den Farben aus dem Spiel, auf dem dunklen Hintergrund der App.
Das Symbol wird erzeugt statt gezeichnet, damit es sich jederzeit in jeder
Groesse neu herstellen laesst.

    python3 tool/make_icon.py
"""

from PIL import Image, ImageDraw

HINTERGRUND = (14, 17, 24, 255)      # tessaBackground
FARBEN = [
    (108, 139, 255, 255),            # Blau
    (61, 214, 160, 255),             # Gruen
    (255, 196, 77, 255),             # Gelb
    (199, 125, 255, 255),            # Violett
]
KANTE = 1024


def bloecke(zeichnung, mitte, feld, radius, luecke):
    """Malt vier Bloecke als 2x2-Muster um [mitte]."""
    for index, farbe in enumerate(FARBEN):
        spalte, zeile = index % 2, index // 2
        links = mitte - feld - luecke // 2 + spalte * (feld + luecke)
        oben = mitte - feld - luecke // 2 + zeile * (feld + luecke)
        zeichnung.rounded_rectangle(
            [links, oben, links + feld, oben + feld],
            radius=radius,
            fill=farbe,
        )


def bild(mit_hintergrund, anteil):
    """Ein Symbol; [anteil] ist die Groesse der Bloecke zur Bildkante."""
    grund = HINTERGRUND if mit_hintergrund else (0, 0, 0, 0)
    bild = Image.new('RGBA', (KANTE, KANTE), grund)
    zeichnung = ImageDraw.Draw(bild)
    feld = int(KANTE * anteil)
    bloecke(zeichnung, KANTE // 2, feld, int(feld * 0.22), int(KANTE * 0.03))
    return bild


if __name__ == '__main__':
    bild(True, 0.30).save('assets/icon/icon.png')
    # Fuer Android: der Vordergrund muss im inneren Drittel bleiben, weil das
    # System die Ecken beschneidet.
    bild(False, 0.20).save('assets/icon/icon_foreground.png')
    print('Symbole in assets/icon/ erzeugt')
