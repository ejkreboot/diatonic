#!/bin/bash

ffmpeg -i "$1" -c:a aac -b:a 192k -movflags +faststart "compressed/${1%.wav}.m4a"
