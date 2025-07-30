# Chorder

**Chorder* (a cousin to the [Slower](https://github.com/ejkreboot/Slower) app) is a simple piano 
keyboard for when you want to quickly play some notes put aren't near a piano. It is intended as a 
support tool for composition and transcription. 

Built using [Flutter](https://flutter.dev). Flutter is cross platform, and thus Slower is too. However, to date it has only been built on MacOS. Builds on Windows and Linux platforms still to come.

---

## ✨ Features

- **Real piano note samples**
- **Play desired intervals and chords** by just playing the root note.
- **Mouse or Keyboard control**

---

## 🖥️ Screenshot

<img src="./screenshot.png" alt="Alt Text" width="300">

---

## 🛠️ Installation

### Coming Soon: Pre-built binary

As binaries become available you will be able to downloae pre-build binaries.

### 🧪 Build from source

1. Install Flutter with macOS desktop support  
   [Flutter installation guide](https://docs.flutter.dev/get-started/install)

2. Clone the repo and build.

```bash
git clone https://github.com/ejkreboot/chorder.git
cd chorder
flutter build macos
cp -R ./build/macos/Build/Products/Release/chorder.app ~/Applications/
```
