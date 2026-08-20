"""Exit 0 if a capture still shows the home indicator, 1 if it is clear.

iOS draws the indicator when an app launches and fades it about two seconds
later, so a capture that lands inside that window ships a pill no other shot
has -- 0.195% of the frame, which is over the publish gate, so the file churns
whenever the machine is slow enough for the shot to arrive early.

    python3 apps/app/Scripts/home-indicator.py <png>
"""
import sys

import numpy as np
from PIL import Image

img = np.asarray(Image.open(sys.argv[1]).convert("L"), dtype=np.int16)
h, w = img.shape
strip = img[h - int(h * 0.045):h - int(h * 0.008), :]
# The pill is the only wide, high-contrast run down there, light on a dark
# ground or dark on a light one, so it is measured against the strip's median
# rather than a fixed level.
runs = (np.abs(strip - np.median(strip)) > 40).sum(axis=1)
sys.exit(0 if (runs > w * 0.25).any() else 1)
