# Test Bed Implementation Plan for rpi-tspl-cups-driver

## Overview

Create a Docker-based test infrastructure to validate DRV/PPD files and TSPL filter output on ARM architectures (armv7, aarch64) using QEMU emulation.

---

## Implementation Status

> Last updated: 2026-01-07 (PR #3) - **All phases complete**

### Phase Summary

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | PPD Validation | ✅ Complete |
| Phase 2 | DRV Compilation | ✅ Complete |
| Phase 3 | Multi-Architecture Docker | ✅ Complete |
| Phase 4 | Filter Output Testing | ✅ Complete |
| Phase 5 | GitHub Actions CI | ✅ Complete |

### Latest CI Results

| Job | Status | Details |
|-----|--------|---------|
| test-aarch64 | ✅ Success | PPD validation + DRV compilation + 5/5 filter tests |
| test-armv7 | ✅ Success | PPD validation + DRV compilation + 5/5 filter tests |
| test-summary | ✅ Success | All tests passed |

**Note:** All tests run in ARM Docker containers (via QEMU emulation) where the filter binary is installed. This enables strict `cupstestppd` validation.

### Filter Test Results

| Test Case | PPD Option | aarch64 | armv7 |
|-----------|------------|---------|-------|
| default | (none) | ✅ PASS | ✅ PASS |
| max-darkness | Darkness=15 | ✅ PASS | ✅ PASS |
| min-speed | zePrintRate=2 | ✅ PASS | ✅ PASS |
| bline-media | zeMediaTracking=BLine | ✅ PASS | ✅ PASS |
| rotated | Rotate=1 | ✅ PASS | ✅ PASS |

### Detailed Test Coverage

#### PPD Validation (6 PPD files)
- [x] `cupstestppd` execution (runs in ARM containers where filter is installed - strict validation)
- [x] `cupsModelNumber: 20` attribute present
- [x] `cupsFilter: raster-tspl` reference present
- [x] `Darkness` option defined
- [x] `zePrintRate` option defined
- [x] `zeMediaTracking` option defined

#### DRV Compilation
- [x] `forc-label-9x00.drv` compiles with `ppdc`
- [x] Generated PPD passes validation

#### Multi-Architecture Testing
- [x] aarch64 Docker image builds and runs
- [x] armv7 Docker image builds and runs
- [x] QEMU emulation works on GitHub Actions x86 runners
- [x] Filter binary executable on both architectures

#### Filter Output Testing
- [x] Filter binary existence check
- [x] Filter binary architecture verification (`file` command)
- [x] **TSPL output generation** (raster files auto-generated in CI)
- [x] **TSPL command parsing** (parse-tspl.py validates output structure)
- [x] **Option validation** (5 test cases: default, darkness, speed, media, rotation)

### Issues Fixed During Implementation

1. **UIConstraints error** - Removed broken references to non-existent `Occurrence`/`SpecifiedPages` options from all PPDs and DRV source
2. **cupstestppd dimension errors** - Fixed page size naming to use Zebra-style convention:
   - Names now use actual point dimensions (e.g., `w288h432` for 288×432 points)
   - Human-readable labels follow the slash (e.g., `w288h432/4"x6" 101.6x152.4mm`)
   - This reduced ~35 "unexpected dimensions" errors to zero
3. **Dimension bugs in 2.5"/2.75" labels** - Fixed pre-existing copy-paste errors where smaller label entries incorrectly used larger PageSize dimensions:
   - `w197h90` (2.75"×1.25"): was using `[213 90]`, now `[197 90]`
   - `w179h142` (2.5"×2"): was using `[283 142]`, now `[179 142]`
   - `w179h71` (2.5"×1"): was using `[283 71]`, now `[179 71]`
4. **Bash arithmetic bug** - Changed `((VAR++))` to `((++VAR))` to avoid exit code 1 with `set -e`
5. **ImageMagick security policy** - Debian blocks PS/PDF output; added `cupsfilter` fallback for raster generation
6. **Ghostscript CUPS device** - Not available in slim containers; `cupsfilter` successfully generates CUPS raster files

---

## Next Steps

### Immediate (Before Merge)

- [x] **Implement raster file generation** - `generate-raster.sh` now creates CUPS raster files using ImageMagick + Ghostscript
- [x] **Auto-generate in CI** - Filter tests automatically generate raster files if missing (via Dockerfiles with ghostscript/imagemagick)
- [x] **Update workflow triggers** - Now triggers on both `main` and `add-test-infrastructure` branches
- [x] **Add filter output validation tests** - 5 test cases implemented:
  - Default options → validates TSPL structure
  - Darkness=15 → validates DENSITY 15
  - zePrintRate=2 → validates SPEED 2
  - zeMediaTracking=BLine → validates BLINE command
  - Rotate=1 → validates DIRECTION 1

### Post-Merge

- [ ] **Add PPD drift detection** - Compare compiled PPD against committed PPD to detect unintended changes

### Future Enhancements

- [ ] **Test matrix for all PPDs** - Currently tests first PPD only; extend to test all PPD files
- [ ] **Negative tests** - Verify filter rejects invalid input gracefully
- [ ] **Performance benchmarks** - Track QEMU emulation overhead
- [ ] **Coverage reporting** - Report which TSPL commands are exercised

### Upstream

- [ ] **Create PR to thorrak/rpi-tspl-cups-driver** - After validation on this fork

---

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
- Job 1: aarch64 tests (QEMU emulated) - PPD validation, DRV compilation, filter tests
- Job 2: armv7 tests (QEMU emulated) - PPD validation, DRV compilation, filter tests
- Jobs run in parallel for faster feedback
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
    branches: [main, add-test-infrastructure]
  pull_request:
    branches: [main, add-test-infrastructure]

env:
  DOCKER_BUILDKIT: 1

jobs:
  # All tests run in ARM containers where filter is installed
  test-aarch64:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-qemu-action@v3
        with:
          platforms: arm64
      - uses: docker/setup-buildx-action@v3
      - name: Build and test aarch64
        run: |
          docker buildx build --platform linux/arm64 --load \
            -t tspl-test-aarch64 -f test/docker/Dockerfile.aarch64 .
          mkdir -p test-output
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
      - name: Build and test armv7
        run: |
          docker buildx build --platform linux/arm/v7 --load \
            -t tspl-test-armv7 -f test/docker/Dockerfile.armv7 .
          mkdir -p test-output
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
          echo "# Test Results Summary" >> $GITHUB_STEP_SUMMARY
          echo "| Architecture | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|--------------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| aarch64 | ${{ needs.test-aarch64.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| armv7 | ${{ needs.test-armv7.result }} |" >> $GITHUB_STEP_SUMMARY
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
