#!/bin/bash

# Debug script for E1 conversion issues
# Usage: ./debug_e1.sh "08-PedalOffForte1Close.flac"

file="$1"
echo "Debugging file: $file"
echo ""

# Extract key number
key_num=$(echo "$file" | grep -o '^[0-9]\+')
echo "Extracted key number: '$key_num'"

# Piano key mapping
keys=(A0 A#0 B0 C1 C#1 D1 D#1 E1 F1 F#1 G1 G#1 A1 A#1 B1 C2 C#2 D2 D#2 E2 F2 F#2 G2 G#2 A2 A#2 B2 C3 C#3 D3 D#3 E3 F3 F#3 G3 G#3 A3 A#3 B3 C4 C#4 D4 D#4 E4 F4 F#4 G4 G#4 A4 A#4 B4 C5 C#5 D5 D#5 E5 F5 F#5 G5 G#5 A5 A#5 B5 C6 C#6 D6 D#6 E6 F6 F#6 G6 G#6 A6 A#6 B6 C7 C#7 D7 D#7 E7 F7 F#7 G7 G#7 A7 A#7 B7 C8)

# Map to note
note="${keys[$((key_num-1))]}"
echo "Mapped note: '$note'"

# Extract volume
volume=$(echo "$file" | grep -o 'Pianissimo\|Piano\|MezzoPiano\|MezzoForte\|Forte' | head -1)
echo "Extracted volume: '$volume'"

# Show what the output filename would be
echo "Output filename would be: '${note}-${volume}.wav'"
echo ""

# Test the actual conversion command
echo "Running conversion command:"
echo "ffmpeg -y -i \"$file\" \"${note}-${volume}.wav\""
echo ""

# Actually run it if both note and volume are extracted
if [ -n "$note" ] && [ -n "$volume" ]; then
    ffmpeg -y -i "$file" "${note}-${volume}.wav"
else
    echo "ERROR: Missing note or volume extraction!"
    echo "Note: '$note'"
    echo "Volume: '$volume'"
fi
