# Regulus Performance Dashboard - Podman Container

Flask-based regulus performance dashboard packaged as a Podman container.

**Requirements:** Podman (RHEL 8/9 or Fedora)

---

## Quick Start

### 1. Install Podman

```bash
sudo dnf install podman
podman --version
```

### 2. Build Container Image

**Using Make (Recommended)**:
```bash
cd /path/to/regulus/REPORT

# Build with latest tag (reports: "Found N built-in report(s)")
make build-container

# Build with custom tag
make build-container-tag TAG=v1.0
```

**Using Build Script**:
```bash
cd /path/to/regulus/REPORT/dashboard/docker
./build.sh
```

The build process automatically detects and reports how many `.json` files are in `sample_data/`:
```
================================================
  Building Dashboard Container Image
================================================

Built-in sample data: dashboard/docker/sample_data
Found 3 built-in report(s)

Building image with tag: latest
...
```

### 3. Add Built-in Sample Data (Optional)

To include sample reports **inside the container image**, add them to `sample_data/` **before building**:

```bash
cd /path/to/regulus/REPORT

# Copy reports to sample_data directory
cp generated/*.json dashboard/docker/sample_data/

# Build container (will show "Found 3 built-in report(s)")
make build-container
```

When the container starts with an empty `/tmp/regulus-data`, it automatically copies built-in reports from `sample_data/` to the mounted directory. This allows users to start the dashboard with sample data immediately.

### 4. Run Container

```bash
# Using the run script
cd dashboard/docker
./run-dashboard.sh

# Or using podman-compose
podman-compose up -d

# Or manually
podman run -d -p 5000:5000 -v /tmp/regulus-data:/app/data:Z regulus-dashboard:latest
```

### 5. Open Browser

```bash
firefox http://localhost:5000
```

**That's it!** Dashboard starts with or without data.

If you included built-in reports in step 3, they will be automatically available when the container starts with an empty data directory.

---

## Managing Data

All data goes in `/tmp/regulus-data/` on your host:

```bash
# Add JSON reports
cp my-report.json /tmp/regulus-data/

# List files
ls -lh /tmp/regulus-data/

# Remove files
rm /tmp/regulus-data/old-report.json

# Click "Reload" button in browser - no restart needed!
```

---

## Built-in Sample Data

The container supports built-in sample reports that are automatically copied when starting with an empty data directory.

### How It Works

1. **Before Build**: Place `.json` files in `dashboard/docker/sample_data/`
2. **During Build**: Make reports how many files were found
3. **Container Start**: `entrypoint.sh` checks if `/app/data` is empty
4. **Auto-Copy**: If empty, copies files from `/app/initial_data/` → `/app/data`
5. **Result**: Built-in reports appear in `/tmp/regulus-data` on the host

### Example Workflow

```bash
# Step 1: Add sample reports before building
cd /path/to/regulus/REPORT
cp generated/bond-report.json dashboard/docker/sample_data/
cp generated/report-dpu.json dashboard/docker/sample_data/

# Step 2: Build container
make build-container
# Output: Found 2 built-in report(s)

# Step 3: Start container with empty directory
rm -rf /tmp/regulus-data/*
podman run -d -p 5000:5000 -v /tmp/regulus-data:/app/data:Z regulus-dashboard:latest

# Step 4: Verify built-in reports were copied
ls /tmp/regulus-data/
# Output: bond-report.json  report-dpu.json
```

### When Built-in Reports Are Copied

- ✅ Container starts **AND** `/tmp/regulus-data` is empty → Reports copied
- ❌ Container starts **AND** `/tmp/regulus-data` has files → Reports **not** copied (existing data preserved)

### Using Make Targets

```bash
cd /path/to/regulus/REPORT

# Build container (detects sample_data files)
make build-container
# Output: Found N built-in report(s)

# Build with custom tag
make build-container-tag TAG=production

# Remove all container images
make clean-container
```

See `REPORT/makefile` for complete list of targets.

---

## Container Management

```bash
# View logs
podman logs regulus-dashboard

# Restart
podman restart regulus-dashboard

# Stop
podman stop regulus-dashboard

# Remove
podman rm -f regulus-dashboard

# Fresh start
podman rm -f regulus-dashboard
rm -rf /tmp/regulus-data/*
./run-dashboard.sh
```

---

## Configuration

### Custom Port

```bash
PORT=8080 ./run-dashboard.sh
```

Or edit `docker-compose.yml`:
```yaml
ports:
  - "8080:5000"
```

### Custom Data Location

```bash
podman run -d \
  --name dashboard \
  -p 5000:5000 \
  -v /path/to/my/reports:/app/data:Z \
  regulus-dashboard:latest
```

Or edit `docker-compose.yml`:
```yaml
volumes:
  - /path/to/my/reports:/app/data:Z
```

### SELinux (RHEL/Fedora)

The `:Z` flag is **required** on SELinux systems. It's included automatically in the scripts.

```bash
# Correct (with :Z)
-v /tmp/regulus-data:/app/data:Z

# Wrong (missing :Z on SELinux systems)
-v /tmp/regulus-data:/app/data
```

---

## Publishing to Registry

### To Quay.io (Recommended)

```bash
# Login
podman login quay.io

# Tag
podman tag regulus-dashboard:latest quay.io/username/regulus-dashboard:v1.0

# Push
podman push quay.io/username/regulus-dashboard:v1.0
```

### Users Pull and Run

```bash
podman pull quay.io/username/regulus-dashboard:v1.0
podman run -d -p 5000:5000 -v /tmp/regulus-data:/app/data:Z quay.io/username/regulus-dashboard:v1.0
```

---

## Using Podman Compose

```bash
# Start
podman-compose up -d

# View logs
podman-compose logs -f

# Stop
podman-compose down

# Rebuild
podman-compose up -d --build
```

Or use built-in `podman compose` (Podman 4.0+):
```bash
podman compose up -d
```

---

## Troubleshooting

### Dashboard starts with no data

**This is normal!** Dashboard shows "No data found" message when `/tmp/regulus-data/` is empty.

**Solution:** Add JSON files and click "Reload" button.

### Port already in use

```bash
# Find what's using the port
sudo ss -tlnp | grep :5000

# Use different port
PORT=8080 ./run-dashboard.sh
```

### Permission denied (SELinux)

**Cause:** Missing `:Z` flag on volume mount.

**Solution:** Scripts include `:Z` automatically. If running manually:
```bash
podman run -v /tmp/regulus-data:/app/data:Z ...
```

Check SELinux context:
```bash
ls -Z /tmp/regulus-data/
```

### Container won't start

```bash
# View logs
podman logs regulus-dashboard

# Check if image exists
podman images | grep regulus-dashboard

# Try interactive mode for debugging
podman run --rm -it regulus-dashboard:latest /bin/bash
```

### Files not showing in dashboard

```bash
# Check files on host
ls -lh /tmp/regulus-data/

# Check files in container
podman exec regulus-dashboard ls -lh /app/data

# Verify mount
podman inspect regulus-dashboard | grep -A 10 Mounts
```

---

## Advanced

### Persistent Data

**Default (temporary):**
```bash
-v /tmp/regulus-data:/app/data:Z
```
Data may be lost on reboot.

**Permanent:**
```bash
-v ~/regulus-reports:/app/data:Z
```
Data persists across reboots.

### Run as Systemd Service

```bash
# Generate service file
podman generate systemd --name regulus-dashboard --new \
  > ~/.config/systemd/user/dashboard.service

# Enable and start
systemctl --user enable dashboard.service
systemctl --user start dashboard.service

# Check status
systemctl --user status dashboard.service

# View logs
journalctl --user -u dashboard.service -f
```

---

## How It Works

**Directory Structure:**
```
regulus/REPORT/
├── dashboard/           # Dashboard application
│   ├── run_dashboard.py
│   ├── templates/
│   ├── static/
│   └── docker/          # Container packaging (this directory)
│       ├── Dockerfile
│       ├── entrypoint.sh        # Copies built-in data if needed
│       ├── run_wrapper.sh       # Startup wrapper
│       ├── build.sh
│       ├── run-dashboard.sh
│       └── sample_data/         # Built-in reports (optional)
└── build_report/        # Core report generation (peer tool)
```

**Data Flow:**
```
Build Time:
  dashboard/docker/sample_data/*.json
    ↓ (copied during build)
  Container: /app/initial_data/*.json

Container Start:
  /app/initial_data/*.json
    ↓ (copied if /app/data is empty)
  Container: /app/data/
    ↕ (mounted with :Z for SELinux)
  Host: /tmp/regulus-data/
    ↓ (scanned by dashboard)
  Browser: http://localhost:5000
```

**No Interactive Prompts:**
- Dashboard detects when running in container (no TTY)
- Starts automatically with or without data
- Shows "No data found" message when empty
- Built-in reports automatically copied on first start

---

## Support

**For help:**
- Dashboard code issues: See `REPORT/dashboard/README.md`
- Container issues: Include output of `podman logs regulus-dashboard`
- Build issues: Include output of `./build.sh`

**Security Notes:**
- Container runs as root (standard for Flask dev servers)
- No authentication (add reverse proxy for production)
- Data directory permissions: Set appropriately for your use case

---

## Files in This Directory

```
docker/
├── Dockerfile              # Container image definition
├── docker-compose.yml      # Compose configuration
├── requirements.txt        # Python dependencies
├── entrypoint.sh          # Container startup script (copies built-in data)
├── run_wrapper.sh         # Dashboard startup wrapper
├── build.sh               # Build script (use make build-container instead)
├── run-dashboard.sh       # Run script
├── .dockerignore          # Build exclusions
├── README.md              # This file
├── sample_data/           # Built-in sample reports (copied to /app/initial_data)
│   └── README.md
├── CONTAINER_BUILD.md     # Complete container build documentation
├── RELOAD_FIX.md          # Dashboard reload functionality docs
└── MAKEFILE_CONTAINER_BUILD.md  # Make targets documentation
```

## Make Targets (REPORT/makefile)

```bash
# Available targets from REPORT directory
make help                           # Show all targets
make build-container                # Build with latest tag
make build-container-tag TAG=v1.0   # Build with custom tag
make clean-container                # Remove all images
```

See `../makefile` (REPORT/makefile) for implementation details.

---

**Ready to use!** Build with make, run with podman. 🚀
