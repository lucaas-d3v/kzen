# Kzen

CPU-first video processing engine and CLI.

Kzen is a minimal, efficient video tool focused on performance using only CPU — built for low-end hardware and full control over the processing pipeline.

---

## Features (WIP)

* Video cutting (via FFmpeg)
* Simple CLI interface
* Designed for future custom processing pipeline

---

## Usage (planned)

```bash
kz cut input.mp4 00:30 01:00 -o output.mp4
```

---

## Install

You need to have Flint installed:

See how to install [here](https://github.com/the-flint-lang/flint#installing-on-debianubuntu-apt-repository---recommended)

Then run:

```bash
flint run install.fl
```

Check installation:

```bash
kz --version
```

---

## Philosophy

* CPU-first (no GPU required)
* Efficiency over brute force
* Build the engine first, UI later

---

## Status

Early development — expect changes.