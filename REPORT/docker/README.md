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

### 2. Extract and Setup

```bash
# Extract tarball
tar -xzf regulus-dashboard-podman.tar.gz

# Copy to your repository
cd ~/path/to/regulus/REPORT
cp -r /path/to/docker ./
```

### 3. Add Sample Data (Optional)

```bash
cd docker
cp ../build_report/dashboard/test_data/*.json sample_data/
```

### 4. Build

```bash
./build.sh
```

### 5. Run

```bash
./run-dashboard.sh
```

### 6. Open Browser

```bash
firefox http://localhost:5000
```

**That's it!** Dashboard starts with or without data.

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
├── build_report/
│   └── dashboard/       # Original dashboard code (untouched)
└── docker/              # Container packaging (this directory)
    ├── Dockerfile
    ├── run_wrapper.py   # Bypasses interactive prompts
    ├── build.sh
    └── run-dashboard.sh
```

**Data Flow:**
```
Host: /tmp/regulus-data/
   ↕ (mounted with :Z for SELinux)
Container: /app/data/
   ↕ (scanned by dashboard)
Browser: http://localhost:5000
```

**No Interactive Prompts:**
- The `run_wrapper.py` script mocks Python's `input()` function
- Dashboard starts automatically with or without data
- Shows "No data found" message when empty
- Your original dashboard code is never modified

---

## Support

**For help:**
- Dashboard code issues: See `../build_report/dashboard/`
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
├── entrypoint.sh          # Container startup script
├── run_wrapper.py         # Bypasses interactive prompts
├── build.sh               # Build script
├── run-dashboard.sh       # Run script
├── .dockerignore          # Build exclusions
├── README.md              # This file
└── sample_data/           # Sample JSON files directory
    └── README.md
```

---

**Ready to use!** Extract, build, run. 🚀
