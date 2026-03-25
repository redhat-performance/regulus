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

The build process automatically detects and reports how many `.json` files are in `generated/`:
```
================================================
  Building Dashboard Container Image
================================================

Built-in reports source: generated/
Found 3 built-in report(s):
  - bond-report.json
  - report-dpu.json
  - report.json

Building image with tag: latest
Build context: REPORT/ (includes dashboard/ and generated/)
...
```

### 3. Built-in Reports (Automatic)

The container automatically includes reports from `REPORT/generated/` when building:

```bash
cd /path/to/regulus/REPORT

# Generate reports first (creates REPORT/generated/*.json)
make report

# Build container (will show "Found N built-in report(s)")
make build-container
```

When the container starts with an empty `/tmp/regulus-data`, it automatically copies built-in reports from `generated/` to the mounted directory. This allows users to start the dashboard with generated data immediately.

### 4. Run Container

```bash
# Recommended: Interactive mode with auto-cleanup (Ctrl+C works!)
podman run --rm -it -p 5000:5000 -v /tmp/regulus-data:/app/data:Z regulus-dashboard:latest

# Or using the run script
cd dashboard/docker
./run-dashboard.sh

# Or using podman-compose
podman-compose up -d

# Or run in background (for long-running deployments)
podman run -d --name dashboard -p 5000:5000 -v /tmp/regulus-data:/app/data:Z regulus-dashboard:latest
```

**Flag explanation:**
- `--rm` = Auto-remove container when stopped (prevents accumulation of stopped containers)
- `-it` = Interactive terminal with signal handling (Ctrl+C works properly)

### 5. Open Browser

```bash
firefox http://localhost:5000
```

**That's it!** Dashboard runs on port 5000 by default and starts with or without data.

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

## Built-in Reports

The container automatically includes reports from `REPORT/generated/` and copies them when starting with an empty data directory.

### How It Works

1. **Generate Reports**: Run `make report` to create reports in `REPORT/generated/`
2. **During Build**: Makefile reports how many files were found in `generated/`
3. **Container Start**: `entrypoint.sh` checks if `/app/data` is empty
4. **Auto-Copy**: If empty, copies files from `/app/initial_data/` → `/app/data`
5. **Result**: Built-in reports appear in `/tmp/regulus-data` on the host

### Example Workflow

```bash
# Step 1: Generate reports (creates REPORT/generated/*.json)
cd /path/to/regulus/REPORT
make report

# Step 2: Build container (automatically includes generated/ reports)
make build-container
# Output: Found 2 built-in report(s): bond-report.json, report-dpu.json

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

# Build container (detects generated/ reports)
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

**Default:** Dashboard runs on port 5000 (defined in `run_dashboard.py`)

**To use a different port:**

```bash
# With run script
PORT=8080 ./run-dashboard.sh

# Or manually - both environment variable AND port mapping must match
podman run -d \
  -e PORT=8080 \
  -p 8080:8080 \
  -v /tmp/regulus-data:/app/data:Z \
  regulus-dashboard:latest

# Explanation:
#   -e PORT=8080        → Tells Flask to listen on port 8080 inside container
#   -p 8080:8080        → Maps host port 8080 to container port 8080
#   Both must match the same port number!
```

**Or edit `docker-compose.yml`**:
```yaml
environment:
  - PORT=8080
ports:
  - "8080:8080"
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

### Ctrl+C doesn't stop container

**Cause:** Container started without `-it` flags.

**Solution:** Use `--rm -it` flags for interactive mode:
```bash
podman run --rm -it -p 5000:5000 -v /tmp/regulus-data:/app/data:Z regulus-dashboard:latest
```

**To stop stuck container:**
```bash
# Find container ID
podman ps

# Stop it
podman stop <container_id>

# Force kill if needed
podman kill <container_id>
```

### Too many stopped containers accumulating

**Cause:** Running without `--rm` flag leaves stopped containers.

**Solution:** Always use `--rm` flag, or clean up periodically:
```bash
# List all containers (including stopped)
podman ps -a

# Remove specific stopped container
podman rm <container_id>

# Remove ALL stopped containers
podman container prune

# Remove all exited containers
podman ps -a --filter "status=exited" -q | xargs podman rm
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
│       └── run-dashboard.sh
├── generated/           # Generated reports (source for built-in reports)
└── build_report/        # Core report generation (peer tool)
```

**Data Flow:**
```
Build Time:
  REPORT/generated/*.json
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
├── Dockerfile              # Container image definition (build context: REPORT/)
├── docker-compose.yml      # Compose configuration
├── requirements.txt        # Python dependencies
├── entrypoint.sh          # Container startup script (copies built-in data)
├── run_wrapper.sh         # Dashboard startup wrapper
├── build.sh               # Build script (use make build-container instead)
├── run-dashboard.sh       # Run script
├── .dockerignore          # Build exclusions
└── README.md              # This file

Note: Built-in reports come from ../generated/ (REPORT/generated/)
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
