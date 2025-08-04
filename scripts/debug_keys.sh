#!/bin/bash

# Debug script to check key mapping and missing samples
# Usage: ./debug_keys.sh

# Piano key mapping: key number to note name (1=A0, 40=C4, 88=C8)
keys=(A0 A#0 B0 C1 C#1 D1 D#1 E1 F1 F#1 G1 G#1 A1 A#1 B1 C2 C#2 D2 D#2 E2 F2 F#2 G2 G#2 A2 A#2 B2 C3 C#3 D3 D#3 E3 F3 F#3 G3 G#3 A3 A#3 B3 C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4 C5 C#5 D5 D#5 E5 F5 F#5 G5 G#5 A5 A#5 B5 C6 C#6 D6 D#6 E6 F6 F#6 G6 G#6 A6 A#6 B6 C7 C#7 D7 D#7 E7 F7 F#7 G7 G#7 A7 A#7 B7 C8)

echo "Key mapping check:"
echo "Key 8 = ${keys[7]} (should be E1)"
echo "Key 17 = ${keys[16]} (what does key 17 map to?)"
echo ""

echo "Looking for E1 in your files:"
ls *E1* 2>/dev/null || echo "No files found with E1 in the name"
echo ""

echo "Checking key numbers 1-20:"
for i in {1..20}; do
    files=$(ls ${i}-* 2>/dev/null | head -1)
    if [ -n "$files" ]; then
        note="${keys[$((i-1))]}"
        echo "Key $i: $files -> $note"
    else
        echo "Key $i: NO FILES FOUND -> ${keys[$((i-1))]}"
    fi
done
