# Test Bed Implementation Plan for rpi-tspl-cups-driver

## Overview

Create a Docker-based test infrastructure to validate DRV/PPD files and TSPL filter output on ARM architectures (armv7, aarch64) using QEMU emulation.

## Directory Structure

```
test/
├── docker/
│   ├── Dockerfile.aarch64           # 64-bit ARM test image
│   ├── Dockerfile.armv7             # 32-bit ARM test image
│   └── docker-compose.yml           # Multi-arch orchestration
├── fixtures/
│   ├── raster/
│   │   └── generate-raster.sh       # Generate CUPS raster test files
│   └── expected/
│       └── 4x6-default.json         # Expected TSPL output structure
├── scripts/
│   ├── run-tests.sh                 # Main test runner
│   ├── test-ppd-validation.sh       # cupstestppd + attribute checks
│   ├── test-drv-compilation.sh      # ppdc compilation tests
│   ├── test-filter-output.sh        # Filter TSPL output validation
│   └── parse-tspl.py                # TSPL command parser/validator
├── lib/
│   └── test-helpers.sh              # Common utilities
└── README.md                        # Test documentation
.github/
└── workflows/
    └── test.yml                     # GitHub Actions CI
```

## Implementation Phases

### Phase 1: PPD Validation (Native x86)
- Run `cupstestppd` on all PPD files
- Verify required attributes: `cupsModelNumber: 20`, `cupsFilter: raster-tspl`
- Verify option names: `Darkness`, `zePrintRate`, `zeMediaTracking`, `FeedOffset`, `Rotate`

### Phase 2: DRV Compilation
- Compile `drv/*.drv` files using `ppdc`
- Validate generated PPDs with `cupstestppd`
- Compare against committed PPD files for drift

### Phase 3: Multi-Architecture Docker Images
- `Dockerfile.aarch64`: debian:bullseye + CUPS + aarch64 filter
- `Dockerfile.armv7`: debian:bullseye + CUPS + armv7 filter (gunzip on install)
- Use QEMU via `docker buildx` for ARM emulation

### Phase 4: Filter Output Testing
- Generate test raster files using Ghostscript `cups` device
- Run filter directly: `PPD=<file> raster-tspl 1 user test 1 "options" < input.ras > output.tspl`
- Parse TSPL output with Python script
- Validate commands: SIZE, DENSITY, SPEED, GAP/BLINE, DIRECTION, BITMAP, PRINT

### Phase 5: GitHub Actions CI
- Job 1: PPD validation + DRV compilation (x86, fast)
- Job 2: aarch64 filter tests (QEMU emulated)
- Job 3: armv7 filter tests (QEMU emulated)
- Artifact upload for test results

## Test Cases

| Test | PPD Options | Expected TSPL |
|------|-------------|---------------|
| Default | none | DENSITY 8, SPEED 4, GAP 3mm |
| Max Darkness | Darkness=15 | DENSITY 15 |
| Min Speed | zePrintRate=2 | SPEED 2 |
| BLine Media | zeMediaTracking=BLine | BLINE (not GAP) |
| Rotated | Rotate=1 | DIRECTION 1 |

## Key Technical Decisions

1. **Base Image**: `debian:bullseye-slim` - matches RPi OS, stable CUPS
2. **ARM Testing**: QEMU user-mode via `docker buildx` - runs actual binaries
3. **Filter Invocation**: Direct (not full CUPS job) - faster, deterministic
4. **Raster Generation**: Ghostscript `cups` device - authentic CUPS raster format

## Critical Files

- `filters/aarch64/cups_2.4.0/raster-tspl` - Primary filter binary
- `filters/armv7/cups_2.2.10/raster-tspl.gz` - Secondary filter (compressed)
- `ppd/sp420.tspl.ppd` - Reference PPD with all options
- `drv/forc-label-9x00.drv` - DRV source for compilation tests
- `docs/RASTER-TSPL.md` - Filter behavior documentation

## Dockerfile.aarch64

```dockerfile
FROM --platform=linux/arm64 debian:bullseye-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    cups \
    cups-filters \
    cups-client \
    libcups2 \
    libcupsimage2 \
    cups-ppdc \
    python3 \
    file \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/test/fixtures /opt/test/output /usr/lib/cups/filter /opt/test/ppd

WORKDIR /opt/test

COPY filters/aarch64/cups_2.4.0/raster-tspl /usr/lib/cups/filter/raster-tspl
RUN chmod 755 /usr/lib/cups/filter/raster-tspl

COPY ppd/ /opt/test/ppd/
COPY drv/ /opt/test/drv/
COPY test/scripts/ /opt/test/scripts/
COPY test/fixtures/ /opt/test/fixtures/
COPY test/lib/ /opt/test/lib/

RUN file /usr/lib/cups/filter/raster-tspl

ENTRYPOINT ["/opt/test/scripts/run-tests.sh"]
```

## Dockerfile.armv7

```dockerfile
FROM --platform=linux/arm/v7 debian:bullseye-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    cups \
    cups-filters \
    cups-client \
    libcups2 \
    libcupsimage2 \
    cups-ppdc \
    python3 \
    file \
    gzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/test/fixtures /opt/test/output /usr/lib/cups/filter /opt/test/ppd

WORKDIR /opt/test

COPY filters/armv7/cups_2.2.10/raster-tspl.gz /tmp/
RUN gunzip /tmp/raster-tspl.gz && \
    mv /tmp/raster-tspl /usr/lib/cups/filter/raster-tspl && \
    chmod 755 /usr/lib/cups/filter/raster-tspl

COPY ppd/ /opt/test/ppd/
COPY drv/ /opt/test/drv/
COPY test/scripts/ /opt/test/scripts/
COPY test/fixtures/ /opt/test/fixtures/
COPY test/lib/ /opt/test/lib/

RUN file /usr/lib/cups/filter/raster-tspl

ENTRYPOINT ["/opt/test/scripts/run-tests.sh"]
```

## docker-compose.yml

```yaml
version: '3.8'

services:
  test-aarch64:
    build:
      context: ../..
      dockerfile: test/docker/Dockerfile.aarch64
      platforms:
        - linux/arm64
    platform: linux/arm64
    volumes:
      - ./output/aarch64:/opt/test/output
    environment:
      - ARCH=aarch64
      - PPD_DIR=/opt/test/ppd
    command: ["--all"]

  test-armv7:
    build:
      context: ../..
      dockerfile: test/docker/Dockerfile.armv7
      platforms:
        - linux/arm/v7
    platform: linux/arm/v7
    volumes:
      - ./output/armv7:/opt/test/output
    environment:
      - ARCH=armv7
      - PPD_DIR=/opt/test/ppd
    command: ["--all"]
```

## GitHub Actions Workflow

```yaml
name: Test CUPS Driver

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  DOCKER_BUILDKIT: 1

jobs:
  validate-ppd:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install CUPS tools
        run: |
          sudo apt-get update
          sudo apt-get install -y cups cups-filters cups-ppdc

      - name: Validate PPD files
        run: |
          for ppd in ppd/*.ppd; do
            echo "Validating $ppd..."
            cupstestppd -v "$ppd" || exit 1
          done

      - name: Check required PPD attributes
        run: |
          for ppd in ppd/*.ppd; do
            echo "Checking $ppd..."
            grep -q "cupsModelNumber.*20" "$ppd" || { echo "Missing cupsModelNumber 20"; exit 1; }
            grep -q "raster-tspl" "$ppd" || { echo "Missing raster-tspl filter"; exit 1; }
          done

      - name: Compile DRV files
        run: |
          mkdir -p build/ppd
          for drv in drv/*.drv; do
            echo "Compiling $drv..."
            ppdc -d build/ppd -l en --lf -v "$drv" || exit 1
          done

      - name: Upload compiled PPDs
        uses: actions/upload-artifact@v4
        with:
          name: compiled-ppds
          path: build/ppd/

  test-aarch64:
    runs-on: ubuntu-latest
    needs: validate-ppd
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
        with:
          platforms: arm64

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and test aarch64
        run: |
          docker buildx build \
            --platform linux/arm64 \
            --load \
            -t tspl-test-aarch64 \
            -f test/docker/Dockerfile.aarch64 \
            .

          mkdir -p test-output
          docker run --rm \
            -v "$PWD/test-output:/opt/test/output" \
            tspl-test-aarch64 --all

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-aarch64
          path: test-output/

  test-armv7:
    runs-on: ubuntu-latest
    needs: validate-ppd
    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3
        with:
          platforms: arm

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build and test armv7
        run: |
          docker buildx build \
            --platform linux/arm/v7 \
            --load \
            -t tspl-test-armv7 \
            -f test/docker/Dockerfile.armv7 \
            .

          mkdir -p test-output
          docker run --rm \
            -v "$PWD/test-output:/opt/test/output" \
            tspl-test-armv7 --all

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-armv7
          path: test-output/

  test-summary:
    runs-on: ubuntu-latest
    needs: [validate-ppd, test-aarch64, test-armv7]
    if: always()
    steps:
      - name: Generate summary
        run: |
          echo "# Test Results Summary" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Test Suite | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|------------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| PPD Validation | ${{ needs.validate-ppd.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| aarch64 Filter | ${{ needs.test-aarch64.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| armv7 Filter | ${{ needs.test-armv7.result }} |" >> $GITHUB_STEP_SUMMARY
```

## TSPL Parser Output Format

The `parse-tspl.py` script outputs JSON for validation:

```json
{
  "size": {"width": 101, "width_unit": "mm", "height": 152, "height_unit": "mm"},
  "reference": {"x": 0, "y": 0},
  "density": 8,
  "speed": 4,
  "direction": 0,
  "gap": {"height": 3, "height_unit": "mm", "offset": 0},
  "cls": true,
  "bitmap": {"x": 0, "y": 0, "width_bytes": 101, "height": 1216, "mode": 1},
  "print_cmd": {"sets": 1, "copies": 1},
  "errors": []
}
```

## Files to Create

| File | Purpose |
|------|---------|
| `test/docker/Dockerfile.aarch64` | ARM64 test container |
| `test/docker/Dockerfile.armv7` | ARM32 test container |
| `test/docker/docker-compose.yml` | Multi-arch orchestration |
| `test/scripts/run-tests.sh` | Main test runner |
| `test/scripts/test-ppd-validation.sh` | PPD validation tests |
| `test/scripts/test-drv-compilation.sh` | DRV compilation tests |
| `test/scripts/test-filter-output.sh` | Filter output tests |
| `test/scripts/parse-tspl.py` | TSPL command parser |
| `test/fixtures/raster/generate-raster.sh` | Test raster generator |
| `test/fixtures/expected/4x6-default.json` | Expected output fixture |
| `test/lib/test-helpers.sh` | Common test utilities |
| `test/README.md` | Test documentation |
| `.github/workflows/test.yml` | CI workflow |

**Total: 13 new files**
