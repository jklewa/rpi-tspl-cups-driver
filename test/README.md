# Test Suite for rpi-tspl-cups-driver

This directory contains Docker-based tests for validating PPD files, DRV compilation, and TSPL filter output on ARM architectures.

## Test Components

### 1. PPD Validation
- Runs `cupstestppd` on all PPD files
- Validates required attributes (`cupsModelNumber: 20`, `cupsFilter: raster-tspl`)
- Checks for correct option names (`Darkness`, `zePrintRate`, `zeMediaTracking`)

### 2. DRV Compilation
- Compiles `.drv` files to PPD using `ppdc`
- Validates generated PPDs
- Detects drift between source DRV and committed PPD files

### 3. Filter Output Validation
- Runs the `raster-tspl` filter with test raster files
- Parses TSPL output commands
- Validates command structure and option values

## Running Tests Locally

### Prerequisites

```bash
# Install Docker and docker-compose
# Enable QEMU for multi-architecture support
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

### Run All Tests (Multi-Architecture)

```bash
# From repository root
cd test/docker
docker-compose up --build
```

### Run Specific Architecture

```bash
# aarch64 only
docker-compose up test-aarch64

# armv7 only
docker-compose up test-armv7
```

### Run Individual Test Suites

```bash
# Build the image
docker build -t tspl-test -f test/docker/Dockerfile.aarch64 .

# PPD validation only
docker run --rm tspl-test --ppd

# DRV compilation only
docker run --rm tspl-test --drv

# All tests
docker run --rm tspl-test --all
```

## Running Tests Natively

If you're on an ARM system (Raspberry Pi), you can run tests without Docker:

```bash
# Install dependencies
sudo apt-get install cups cups-filters cups-ppdc python3

# Run all tests
./test/scripts/run-tests.sh --all

# Run specific suites
./test/scripts/run-tests.sh --ppd
./test/scripts/run-tests.sh --drv
./test/scripts/run-tests.sh --filter
```

## Test Output

Test results are written to `test/docker/output/<arch>/`:

- `*.cupstestppd.log` - PPD validation logs
- `*.ppdc.log` - DRV compilation logs
- `*.tspl` - Raw TSPL filter output
- `*.parsed.json` - Parsed TSPL command structure

## CI/CD Integration

Tests run automatically on GitHub Actions for:
- Pull requests to `main` branch
- Pushes to `main` branch

See `.github/workflows/test.yml` for the workflow configuration.

## Test Cases

| Test | PPD Options | Expected TSPL Commands |
|------|-------------|------------------------|
| Default | none | DENSITY 8, SPEED 4, GAP |
| Max Darkness | Darkness=15 | DENSITY 15 |
| Min Speed | zePrintRate=2 | SPEED 2 |
| BLine Media | zeMediaTracking=BLine | BLINE (not GAP) |
| Rotated | Rotate=1 | DIRECTION 1 |

## Adding New Tests

1. Create test raster files in `test/fixtures/raster/`
2. Add expected output in `test/fixtures/expected/`
3. Update test scripts in `test/scripts/`
4. Document in this README

## Troubleshooting

### QEMU Emulation is Slow

ARM emulation on x86 can be 5-10x slower. This is expected. CI tests may take several minutes.

### Filter Tests Skipped

Filter output tests require CUPS raster input files. These are not included in the repository. To generate them, see `test/fixtures/raster/generate-raster.sh`.

### cupstestppd Warnings

Some PPD warnings are expected and documented in `docs/RASTER-TSPL.md`. Only FAIL status indicates an issue.
