#!/usr/bin/env bash
# Wallpaper backdrops for the mockup page (sharp + a pre-blurred copy for the frosted look), and the reference still.
# Output goes to ./img (not committed). Needs ImageMagick.
set -euo pipefail
cd "$(dirname "$0")"
BG=../../backgrounds
mkdir -p img
mk() {
  magick "$BG/$1" -resize 1920x1200^ -gravity center -extent 1920x1200 -resize 1280x800 -quality 72 "img/$2.jpg"
  magick "$BG/$1" -resize 1920x1200^ -gravity center -extent 1920x1200 -resize 320x200 -blur 0x5 -quality 60 "img/$2-b.jpg"
}
mk 1-annihilation_89fcOJ.jpg w1   # tile wall (the theme default)
mk annihilation-077.jpg      w2   # forest
mk annihilation-119.jpg      w3   # the cell division still
magick "$BG/annihilation-119.jpg" -resize 1100x -quality 78 img/ref119.jpg
