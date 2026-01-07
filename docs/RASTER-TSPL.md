# raster-tspl Filter Documentation

This document describes the `raster-tspl` CUPS filter used in this project, its origins, capabilities, and current limitations.

## Overview

The `raster-tspl` filter converts CUPS raster data to TSPL (TSC Printer Language) commands for thermal label printers. It is a modified version of the standard CUPS `rastertolabel` filter.

## Source Code

| Repository | Branch/Commit | Description |
|------------|---------------|-------------|
| [proski/cups](https://github.com/proski/cups) | [9ade138](https://github.com/proski/cups/commit/9ade138db4387ed016f70feb11a3b7a05daf04ca) | Original BEEPRT implementation by proski |
| [thorrak/cups](https://github.com/thorrak/cups) | `2.2.10_beeprt` | Fork used to compile distributed binaries |

The implementation adds a `BEEPRT` (0x14) case to `filter/rastertolabel.c`, supporting Beeprt, Rollo, and Munbyn thermal label printers.

### Key Source File

https://github.com/thorrak/cups/blob/2.2.10_beeprt/filter/rastertolabel.c

## How It Works

1. CUPS converts the print job to raster format (`application/vnd.cups-raster`)
2. The filter reads the raster data and PPD options
3. Generates TSPL commands: `SIZE`, `REFERENCE`, `DIRECTION`, `GAP`/`BLINE`, `DENSITY`, `SPEED`
4. Converts 8-bit grayscale pixels to 1-bit using threshold of 200 (inverted)
5. Sends bitmap data and `PRINT 1,1` command

## PPD Options Read by Filter

The filter reads these specific PPD option names via `ppdFindMarkedChoice()`:

| Option Name | Purpose | TSPL Command | Values |
|-------------|---------|--------------|--------|
| `AdjustHoriaontal` | Reference X position | `REFERENCE x,y` | Integer (dots) |
| `AdjustVertical` | Reference Y position | `REFERENCE x,y` | Integer (dots) |
| `Rotate` | Print orientation | `DIRECTION n` | 0, 1 |
| `zeMediaTracking` | Media type | `GAP` / `BLINE` | Gap, BLine, Continuous |
| `GapOrMarkHeight` | Gap/mark height | `GAP h,o` | Integer (dots) |
| `GapOrMarkOffset` | Gap/mark offset | `GAP h,o` | Integer (dots) |
| `FeedOffset` | Feed offset after print | `OFFSET n` | Integer (dots) |
| `Darkness` | Print density | `DENSITY n` | 0-15 |
| `zePrintRate` | Print speed | `SPEED n` | 2-6 (inches/sec) |
| `Autodotted` | Auto-dot feature | (internal) | Boolean |

**Note:** `AdjustHoriaontal` is intentionally misspelled to match the original Munbyn PPD files.

## PPD Requirements

For the filter to recognize a printer, the PPD must specify:

```
*cupsModelNumber: 20
*cupsFilter: "application/vnd.cups-raster 0 raster-tspl"
```

The `cupsModelNumber: 20` (0x14 in hex) triggers the BEEPRT code path.

## PPD Options Status

The PPD files have been updated to use the correct option names that the filter expects. The following options are functional:

| PPD Option | TSPL Command | Status |
|------------|--------------|--------|
| `Darkness` | `DENSITY n` | Working |
| `zePrintRate` | `SPEED n` | Working |
| `FeedOffset` | `OFFSET n` | Working |
| `zeMediaTracking` | `GAP`/`BLINE` | Working |
| `Rotate` | `DIRECTION n` | Working |
| `AdjustVertical` | `REFERENCE x,y` | Working |
| `AdjustHoriaontal` | `REFERENCE x,y` | Working |

**Note:** `AdjustHoriaontal` is intentionally misspelled to match the original Munbyn PPD files and filter implementation.

### Options Not Implemented in Filter

These options from iDPRT's original driver are not supported by the raster-tspl filter:

| Option | Status |
|--------|--------|
| `FowardOffset` | Not implemented |
| `MediaMethod` | Not implemented |
| `MirrorImage` | Not implemented |
| `NegativeImage` | Not implemented |
| `PostAction` | Not implemented |

## Known Limitations

### 1. Fixed Grayscale Threshold

The filter converts grayscale to black/white using a hardcoded threshold of 200. This may cause inverted output on some printers. The only fix requires recompiling the filter with a different threshold.

### 2. Limited Resolution Support

- 203 DPI: Tested and working
- 300 DPI: Implemented but untested

### 3. AirPrint Default Page Size

iOS AirPrint may select incorrect default page sizes due to a known iOS bug ([apple/cups#6009](https://github.com/apple/cups/issues/6009)). Workarounds:

1. **Remove unused page sizes** from the PPD to limit iOS choices
2. **Disable custom page sizes** by setting `*CustomPageSize False:` in the PPD
3. **Set media-default** via `lpadmin -p PRINTER -o media-default=w100h150`

## Building the Filter

The `raster-tspl` filter is a modified version of CUPS `rastertolabel`. To rebuild:

### Prerequisites

```bash
# Debian/Ubuntu/Raspbian
sudo apt-get install build-essential autoconf libcups2-dev libcupsimage2-dev
```

### Build Steps

```bash
# Clone the modified CUPS source
git clone https://github.com/thorrak/cups.git
cd cups
git checkout 2.2.10_beeprt

# Configure and build
./configure
make

# The filter binary will be at:
# filter/rastertolabel

# Install (rename to raster-tspl)
sudo cp filter/rastertolabel /usr/lib/cups/filter/raster-tspl
sudo chmod 755 /usr/lib/cups/filter/raster-tspl
```

### Cross-Compiling for Raspberry Pi

For cross-compilation from x86 to ARM, you'll need the appropriate ARM toolchain and CUPS libraries compiled for the target architecture.

## TSPL Commands Generated

Example output for a 4x6 label at 203 DPI:

```
SIZE 101 mm,152 mm
REFERENCE 0,0
DIRECTION 0
GAP 3 mm,0 mm
DENSITY 8
SPEED 4
CLS
BITMAP 0,0,101,1216,1,<binary data>
PRINT 1,1
```

## References

- [Hackaday Project](https://hackaday.io/project/184984-cheap-poshmark-label-printer-iphone-airprint) - Original inspiration
- [proski's commit](https://github.com/proski/cups/commit/9ade138db4387ed016f70feb11a3b7a05daf04ca) - BEEPRT implementation
- [thorrak's comparison](https://github.com/OpenPrinting/cups/compare/v2.2.10...thorrak:cups:2.2.10_beeprt) - Full diff of changes
- [TSPL Programming Manual](https://www.tscprinters.com/cms/upload/download_en/TSPL_TSPL2_Programming.pdf) - TSC printer command reference
