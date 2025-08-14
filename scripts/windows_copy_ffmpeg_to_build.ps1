$source = ".\windows\runner\resources\ffmpeg.exe"
$destDir = ".\build\windows\x64\runner\Resources"
New-Item -ItemType Directory -Force -Path $destDir | Out-Null
Copy-Item $source $destDir -Force