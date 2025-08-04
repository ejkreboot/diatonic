#!/bin/bash

# Advanced gain boosting script with multiple options
# Usage: ./boost_gain_advanced.sh [method] [boost_amount]

METHOD=${1:-volume}  # volume, compand, or normalize
BOOST=${2:-6}        # boost amount in dB

echo "Boosting MezzoForte samples using method: $METHOD, boost: ${BOOST}dB"

case $METHOD in
    "volume")
        # Simple volume boost - cleanest for moderate boosts
        MULTIPLIER=$(echo "scale=2; e(l(10) * $BOOST / 20)" | bc -l)
        echo "Using volume multiplier: $MULTIPLIER"
        for file in *-MezzoForte.wav; do
            if [ -f "$file" ]; then
                echo "Processing: $file"
                ffmpeg -i "$file" -filter:a "volume=${MULTIPLIER}" -y "${file%.wav}_boosted.wav"
                mv "${file%.wav}_boosted.wav" "boosted/$file"
            fi
        done
        ;;
    
    "compand")
        # Dynamic compression + boost - prevents clipping, more natural
        for file in *-MezzoForte.wav; do
            if [ -f "$file" ]; then
                echo "Processing: $file"
                ffmpeg -i "$file" -filter:a "compand=attacks=0.3:decays=0.8:points=-90/-90|-60/-50|-40/-30|-20/-15|-5/-5|0/-3|20/-3" -filter:a "volume=${BOOST}dB" -y "${file%.wav}_boosted.wav"
                mv "${file%.wav}_boosted.wav" "$file"
            fi
        done
        ;;
    
    "normalize")
        # Normalize to peak, then boost - most consistent levels
        for file in *-MezzoForte.wav; do
            if [ -f "$file" ]; then
                echo "Processing: $file"
                ffmpeg -i "$file" -filter:a "dynaudnorm=f=500:g=31:s=0.95" -filter:a "volume=${BOOST}dB" -y "${file%.wav}_boosted.wav"
                mv "${file%.wav}_boosted.wav" "$file"
            fi
        done
        ;;
    
    *)
        echo "Unknown method. Use: volume, compand, or normalize"
        exit 1
        ;;
esac

echo "Done! All MezzoForte samples processed."
