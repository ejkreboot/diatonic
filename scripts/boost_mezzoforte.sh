#!/bin/bash

# Script to boost gain on MezzoForte samples
# Usage: ./boost_mezzoforte.sh

echo "Boosting gain on MezzoForte samples..."

# Method 1: Simple volume boost (recommended)
# Boost by 6dB (doubles the perceived loudness)
for file in *-MezzoForte.wav; do
    if [ -f "$file" ]; then
        echo "Processing: $file"
        ffmpeg -i "$file" -filter:a "volume=2.0" -y "${file%.wav}_boosted.wav"
        # Replace original with boosted version
        # mv "${file%.wav}_boosted.wav" "$file"
    fi
done

echo "Done! All MezzoForte samples have been boosted by 6dB."
