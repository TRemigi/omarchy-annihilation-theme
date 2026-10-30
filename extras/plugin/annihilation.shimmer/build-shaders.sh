#!/bin/bash

# Compile shaders/*.frag to the .qsb files the plugin loads. The compiled files
# are committed so installing the plugin does not need qt6-shadertools.

set -euo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/shaders"
QSB=${QSB:-/usr/lib/qt6/bin/qsb}

for src in *.frag; do
  "$QSB" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$src.qsb" "$src"
  echo "built shaders/$src.qsb"
done
