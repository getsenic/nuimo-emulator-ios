#!/bin/bash
f="../../../appstore-assets/AppIcon.png"

sips --resampleWidth  40 "${f}" --out "./Icon-40.png"
sips --resampleWidth  80 "${f}" --out "./Icon-40@2x.png"
sips --resampleWidth 120 "${f}" --out "./Icon-40@3x.png"
sips --resampleWidth 120 "${f}" --out "./Icon-60@2x.png"
sips --resampleWidth 180 "${f}" --out "./Icon-60@3x.png"
sips --resampleWidth  76 "${f}" --out "./Icon-76.png"
sips --resampleWidth 152 "${f}" --out "./Icon-76@2x.png"
sips --resampleWidth 167 "${f}" --out "./Icon-iPadPro.png"
sips --resampleWidth  29 "${f}" --out "./Icon-Small.png"
sips --resampleWidth  58 "${f}" --out "./Icon-Small@2x.png"
sips --resampleWidth  87 "${f}" --out "./Icon-Small@3x.png"
