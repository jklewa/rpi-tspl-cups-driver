# Test Infrastructure for rpi-tspl-cups-driver

## Overview

Docker-based test infrastructure that validates PPD files, DRV compilation, and TSPL filter output on ARM architectures (aarch64, armv7) using QEMU emulation. All tests run in ARM containers where the filter binary is installed, enabling strict validation.

---

## Quick Start

```bash
# Run tests locally (requires Docker with buildx)
docker buildx build --platform linux/arm64 --load \
  -t tspl-test -f test/docker/Dockerfile.aarch64 .
docker run --rm -v "$PWD/test-output:/opt/test/output" tspl-test --all
```

---

## CI Status

| Architecture | Tests | Status |
|--------------|-------|--------|
| aarch64 (ARM64) | PPD + DRV + Filter | ✅ Passing |
| armv7 (ARM32) | PPD + DRV + Filter | ✅ Passing |

**Workflow triggers:** `push` to main, `pull_request` targeting main

---

## Test Suites

### 1. PPD Validation

Validates all 6 PPD files using `cupstestppd` with filter installed:

```bash
cupstestppd -W translations ppd/*.ppd
```

**Checks:**
- `cupstestppd` passes (with `-W translations` to suppress incomplete zh_CN translations)
- `cupsModelNumber: 20` attribute present
- `cupsFilter: raster-tspl` reference present
- Required options: `Darkness`, `zePrintRate`, `zeMediaTracking`

### 2. DRV Compilation

Compiles DRV source files and validates the generated PPDs:

```bash
ppdc -d build/ppd -l en --lf -v drv/*.drv
cupstestppd -W translations build/ppd/*.ppd
```

### 3. Filter Output Tests

Runs the TSPL filter with various options and validates output:

| Test | PPD Option | Validates |
|------|------------|-----------|
| default | (none) | TSPL structure, DENSITY 8, SPEED 4 |
| max-darkness | Darkness=15 | DENSITY 15 |
| min-speed | zePrintRate=2 | SPEED 2 |
| bline-media | zeMediaTracking=BLine | BLINE command |
| rotated | Rotate=1 | DIRECTION 1 |

---

## Directory Structure

```
test/
├── docker/
│   ├── Dockerfile.aarch64      # ARM64 test container
│   ├── Dockerfile.armv7        # ARM32 test container
│   └── docker-compose.yml      # Local multi-arch testing
├── fixtures/
│   ├── raster/
│   │   └── generate-raster.sh  # CUPS raster file generator
│   └── expected/
│       └── 4x6-default.json    # Expected TSPL output
├── scripts/
│   ├── run-tests.sh            # Main test orchestrator
│   ├── test-ppd-validation.sh  # cupstestppd + attribute checks
│   ├── test-drv-compilation.sh # ppdc compilation tests
│   ├── test-filter-output.sh   # Filter TSPL output validation
│   └── parse-tspl.py           # TSPL command parser
└── lib/
    └── test-helpers.sh         # Common utilities

.github/workflows/
└── test.yml                    # GitHub Actions CI
```

---

## GitHub Actions Workflow

```yaml
name: Test CUPS Driver

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-aarch64:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
        with:
          platforms: arm64
      - uses: docker/setup-buildx-action@v3
      - name: Build and test
        run: |
          docker buildx build --platform linux/arm64 --load \
            -t tspl-test-aarch64 -f test/docker/Dockerfile.aarch64 .
          docker run --rm -v "$PWD/test-output:/opt/test/output" \
            tspl-test-aarch64 --all
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-aarch64
          path: test-output/

  test-armv7:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
        with:
          platforms: arm
      - uses: docker/setup-buildx-action@v3
      - name: Build and test
        run: |
          docker buildx build --platform linux/arm/v7 --load \
            -t tspl-test-armv7 -f test/docker/Dockerfile.armv7 .
          docker run --rm -v "$PWD/test-output:/opt/test/output" \
            tspl-test-armv7 --all
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-armv7
          path: test-output/

  test-summary:
    runs-on: ubuntu-latest
    needs: [test-aarch64, test-armv7]
    if: always()
    steps:
      - name: Generate summary
        run: |
          echo "# Test Results" >> $GITHUB_STEP_SUMMARY
          echo "| Architecture | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|--------------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| aarch64 | ${{ needs.test-aarch64.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| armv7 | ${{ needs.test-armv7.result }} |" >> $GITHUB_STEP_SUMMARY
```

---

## Technical Details

### Why ARM Containers?

All tests run in ARM Docker containers (via QEMU emulation) because:

1. **Filter binary is ARM-only** - The `raster-tspl` filter is compiled for ARM architectures
2. **Accurate cupstestppd validation** - Without the filter installed, cupstestppd reports "missing filter" errors
3. **Real architecture testing** - Tests run on the actual target platform

### CUPS Raster Generation

Test raster files are auto-generated in CI using `cupsfilter`:

```bash
cupsfilter -p ppd/sp420.tspl.ppd -o PageSize=w288h432 \
  -i application/pdf -o application/vnd.cups-raster \
  test-image.pdf > output.ras
```

### TSPL Parser

The `parse-tspl.py` script extracts and validates TSPL commands:

```json
{
  "size": {"width": 101, "width_unit": "mm", "height": 152, "height_unit": "mm"},
  "density": 8,
  "speed": 4,
  "direction": 0,
  "gap": {"height": 3, "height_unit": "mm"},
  "bitmap": {"x": 0, "y": 0, "width_bytes": 101, "height": 1216},
  "print_cmd": {"sets": 1, "copies": 1}
}
```

---

## Issues Fixed

### PPD Page Size Naming

Converted page size names to Zebra-style convention where `wXXhYY` uses actual point dimensions:

- **Before:** `w100h150/4"x6"(101.6mm x 152.4mm)` (XX/YY were mm values)
- **After:** `w288h432/4"x6" 101.6x152.4mm` (XX/YY are points: 72 per inch)

This fixed ~35 `cupstestppd` "unexpected dimensions" errors.

### Dimension Bugs

Fixed copy-paste errors where 2.5" and 2.75" labels used wrong PageSize dimensions:

| Label | Was | Fixed |
|-------|-----|-------|
| w197h90 (2.75"×1.25") | `[213 90]` | `[197 90]` |
| w179h142 (2.5"×2") | `[283 142]` | `[179 142]` |
| w179h71 (2.5"×1") | `[283 71]` | `[179 71]` |

### Other Fixes

- **UIConstraints error** - Removed broken `Occurrence`/`SpecifiedPages` references
- **Bash arithmetic** - Changed `((VAR++))` to `((++VAR))` for `set -e` compatibility
- **Raster generation** - Added `cupsfilter` fallback when ImageMagick/Ghostscript fail

---

## Future Enhancements

- [ ] **PPD drift detection** - Compare compiled PPD against committed PPD
- [ ] **Test all PPDs** - Currently tests sp420 only; extend to all 6 PPD files
- [ ] **Negative tests** - Verify filter handles invalid input gracefully
- [ ] **Performance benchmarks** - Track QEMU emulation overhead

---

## Key Files

| File | Purpose |
|------|---------|
| `filters/aarch64/cups_2.4.0/raster-tspl` | ARM64 filter binary |
| `filters/armv7/cups_2.2.10/raster-tspl.gz` | ARM32 filter binary (compressed) |
| `ppd/sp420.tspl.ppd` | Reference PPD used in filter tests |
| `drv/forc-label-9x00.drv` | DRV source for compilation tests |
