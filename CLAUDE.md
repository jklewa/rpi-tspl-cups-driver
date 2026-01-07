# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a CUPS driver for TSPL (Thermal Sensitive Printing Language) based label printers on Raspberry Pi platforms. It provides pre-compiled filter binaries and PPD configuration files for armv7 and aarch64 architectures. This is an unofficial, community-driven project.

## Architecture

```
User Application → CUPS Daemon → PPD + Raster Data → raster-tspl Filter → TSPL Commands → Printer
```

**Components:**
- **ppd/**: PostScript Printer Description files defining printer capabilities (resolution, media sizes, darkness, speed, etc.)
- **drv/**: CUPS Driver Definition source files (can be compiled to PPD)
- **filters/**: Pre-compiled filter binaries that convert CUPS raster format to TSPL commands
  - `armv7/cups_2.2.10/raster-tspl.gz` - 32-bit ARM (compressed)
  - `aarch64/cups_2.4.0/raster-tspl` - 64-bit ARM

The filter is based on Proski's modifications to CUPS rastertolabel (commit bfdcaad258f58ab512da0bdc1457dc963a25cf8c from proski/cups).

## Build Commands

This is primarily a binary distribution repository. The only build operation is compiling DRV files to PPD:

```bash
# Compile DRV to PPD (requires ppdc from cups-filters package)
ppdc -d ./ppd -l en --lf -v ./drv/forc-label-9x00.drv
```

## Installation

1. **Install PPD**: Use CUPS web interface (http://localhost:631) → Add Printer → select PPD from `ppd/` directory
2. **Install filter**:
   ```bash
   # For armv7:
   gunzip filters/armv7/cups_2.2.10/raster-tspl.gz
   sudo cp filters/armv7/cups_2.2.10/raster-tspl /usr/lib/cups/filter/

   # For aarch64:
   sudo cp filters/aarch64/cups_2.4.0/raster-tspl /usr/lib/cups/filter/

   sudo chmod 755 /usr/lib/cups/filter/raster-tspl
   ```
3. **Restart CUPS**: `sudo systemctl restart cups`

## Supported Printers

**Tested**: iDPRT SP420, FORC LABEL 9250 (9x00 series)

**Expected to work**: iDPRT SP310/SP320/SP410, HPRT SL42, and other TSPL-based thermal label printers (Beeprt, Rollo, Munbyn)

## Key PPD Parameters

All PPD files use:
- `cupsModelNumber: 20` (required for this driver)
- `cupsFilter: "application/vnd.cups-raster 0 raster-tspl"`
- Grayscale only (ColorDevice: False)

## PPD Options

The PPD files use option names that match the raster-tspl filter expectations:

| PPD Option | Purpose | TSPL Command |
|------------|---------|--------------|
| `Darkness` | Print density (0-15) | `DENSITY n` |
| `zePrintRate` | Print speed (2-4 in/sec) | `SPEED n` |
| `zeMediaTracking` | Media type (Gap/BLine/Continuous) | `GAP`/`BLINE` |
| `FeedOffset` | Feed offset (-12 to 12mm) | `OFFSET n` |
| `Rotate` | Print orientation (0/1) | `DIRECTION n` |
| `AdjustVertical` | Vertical position adjustment | `REFERENCE x,y` |
| `AdjustHoriaontal` | Horizontal position adjustment | `REFERENCE x,y` |

**Note:** `AdjustHoriaontal` is intentionally misspelled to match the filter implementation.

## Known Issues

**Inverted print output**: The filter's automatic grayscale-to-black/white threshold may cause inverted colors on some printers. Different printers may need different thresholds (requires filter recompilation).

**AirPrint default page size**: iOS may select wrong default page sizes. Remove unused sizes from PPD or disable custom page sizes. See [apple/cups#6009](https://github.com/apple/cups/issues/6009).

## Documentation

- [docs/RASTER-TSPL.md](docs/RASTER-TSPL.md) - Filter source code, PPD options, and limitations
