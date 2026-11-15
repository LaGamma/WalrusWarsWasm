# Walrus Wars!

[![Play in Browser](https://img.shields.io/badge/%E2%96%B6_Play_in_Browser-WalrusWars-AA00FF?style=for-the-badge&logo=webassembly&logoColor=white)](https://lagamma.github.io/WalrusWarsWasm/)

A fast-paced arctic arena brawler ported to **Mojo** on top of [gammaraylib](https://github.com/LaGamma/gammaraylib), targeting both **Native Linux** (GLFW + OpenGL 4.6) and **WebAssembly** (Emscripten + WebGL 2 + WebAudio).

> **Play in your browser:** [Launch Walrus Wars](https://lagamma.github.io/WalrusWarsWasm/)

## Prerequisites
* [uv](https://astral.sh) (manages the Mojo toolchain)
* **Native Linux**: `libglfw3`, `libGL`, `libpng16`, `libturbojpeg`, `libasound2`
* **WebAssembly**: [Emscripten SDK (`emcc`)](https://emscripten.org)

## Quick Start

1. **Clone with submodules:**
   ```bash
   git clone --recurse-submodules https://github.com<username>/WalrusWarsWasm.git
   cd WalrusWarsWasm
   ```

2. **Install dependencies:**
   ```bash
   uv sync
   ```

3. **Build & run Native:**
   ```bash
   python3 build.py native --run
   ```

4. **Build & serve WebAssembly:**
   ```bash
   python3 build.py wasm --run
   ```
   Then open `http://localhost:8000` in your browser.
