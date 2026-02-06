# Regulus ElasticSearch MCP Server

Model Context Protocol (MCP) server for interacting with Regulus benchmark data in ElasticSearch through **Claude Desktop, Cline, or other MCP clients**.

## What is MCP?

MCP (Model Context Protocol) is an **open standard** that allows AI assistants to interact with external tools and data sources. The Regulus MCP server provides 6 specialized tools for querying and managing ElasticSearch benchmark data.

### Supported Clients

The MCP server works with any MCP-compatible client:

1. **Claude Desktop** (macOS, Windows)
   - Official Anthropic desktop app
   - Natural language queries through Claude AI
   - Best for interactive exploration

2. **Cline** (VS Code Extension)
   - AI coding assistant for VS Code
   - Great for developers and automation
   - Works on Linux, macOS, Windows

3. **MCP Inspector** (Development Tool)
   - Interactive testing tool
   - Useful for development and debugging
   - Install: `npm install -g @modelcontextprotocol/inspector`

4. **Custom Clients**
   - Any application implementing the MCP protocol
   - Use the stdio transport interface
   - See: https://modelcontextprotocol.io/

### Standalone CLI (No MCP Client Required)

For users who don't want to set up an MCP client, the **standalone CLI** provides direct access to all server functions without requiring Claude Desktop, Cline, or any other frontend.

## Features

The Regulus ES MCP server provides these tools:

1. **list_batches** - List all upload batches with document counts
2. **get_batch_info** - Get detailed information about a specific batch
3. **search_benchmarks** - Search for benchmark results with filters (benchmark type, model, NIC, throughput)
4. **compare_batches** - Compare performance between two upload batches
5. **delete_batch** - Delete all documents in a batch (with confirmation)
6. **get_index_stats** - Get overall index statistics

### Understanding CPU Metrics

**IMPORTANT**: The `CPU` value in search results is **NOT a percentage**.

- **CPU is an aggregated sum** of CPU utilization (mpstat: sum of % busy across all CPUs)
- `CPU: 44.8` means 44.8 CPU-equivalents of work were consumed
- For **internode tests**: Each test uses 2 workers (sender + receiver on different nodes)
- When you see `CPUs: 2` in config, that's per worker (4 CPUs total for internode)
- The CPU busy metric represents aggregated utilization across both workers

See `SEARCH_EXAMPLES.md` for detailed metric interpretation and analysis examples.

## Installation

### Prerequisites

- **Python 3.11 or higher** (Required for fastmcp package compatibility)
  - Python 3.6-3.10 are **not supported** due to dependency requirements
  - If `python3.11` is not available, install it first or use the containerized approach
- Access to your ElasticSearch instance

### Setup

1. **Create a virtual environment:**

```bash
cd $REG_ROOT/REPORT/mcp_server

# IMPORTANT: Use Python 3.11 or higher
python3.11 -m venv .venv
# If python3.11 is not in PATH, use the full path:
# /usr/bin/python3.11 -m venv .venv

source .venv/bin/activate
```

2. **Install dependencies:**

```bash
pip install -r requirements.txt
```

**Note:** The requirements.txt has been fixed to remove the non-existent `mcp>=1.0.0` package. Only `fastmcp` and `httpx` are needed.

3. **Configure ElasticSearch index pattern:**

```bash
# Set your ES connection (or source from lab.config)
export ES_URL='https://admin:password@your-es-host.com'

# Test run (ES_INDEX is hardcoded in es_integration/es_config.py)
python regulus_es_mcp.py
```

The server should start without errors (it will wait for stdio input from an MCP client).

### Understanding Index Rollover

The Regulus ElasticSearch index uses **ISM (Index State Management) with rollover**:

- **Write alias**: `regulus-results-write` (always points to the current active index for uploads)
- **Actual indices**: `regulus-results-000001`, `regulus-results-000002`, etc. (created on rollover)
- **Query pattern**: `regulus-results-*` (hardcoded in `REPORT/es_integration/es_config.py`)

**Why hardcoded?**
- ES_INDEX is tied to the ISM policy and rollover infrastructure
- Changing it would break queries and uploads
- Users should not modify it unless they're infrastructure experts
- Automatically queries across all rollover indices for complete historical data

**Configuration Location:**
The index pattern is defined in `REPORT/es_integration/es_config.py` with sensible defaults that work out-of-the-box.

## Configuration for MCP Clients

### Option A: Claude Desktop (macOS, Windows)

**Note:** Claude Desktop is currently only available for macOS and Windows.

Add the MCP server to your Claude Desktop configuration file:

**Location:**
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Windows: `%APPDATA%\Claude\claude_desktop_config.json`

**Configuration:**

```json
{
  "mcpServers": {
    "regulus-elasticsearch": {
      "command": "/path/to/regulus/REPORT/mcp_server/.venv/bin/python",
      "args": [
        "/path/to/regulus/REPORT/mcp_server/regulus_es_mcp.py"
      ],
      "env": {
        "ES_URL": "https://username:password@your-es-host.amazonaws.com"
      }
    }
  }
}
```

**Important:**
- Use absolute paths for both the Python interpreter and the script
- Include your ES credentials in the `ES_URL`
- ES_INDEX is hardcoded as `regulus-results-*` (no need to configure)
- Restart Claude Desktop after editing the config

---

### Option B: Cline (VS Code Extension - All Platforms)

**Cline** is an AI coding assistant VS Code extension that supports MCP servers. Great for Linux users and developers!

1. **Install Cline Extension**
   - Open VS Code
   - Install "Cline" extension from the marketplace
   - Or: https://marketplace.visualstudio.com/items?itemName=saoudrizwan.claude-dev

2. **Configure MCP Server**

   Open Cline settings (VS Code: Settings → Extensions → Cline → Edit in settings.json) and add:

   ```json
   {
     "cline.mcpServers": {
       "regulus-elasticsearch": {
         "command": "/path/to/regulus/REPORT/mcp_server/.venv/bin/python",
         "args": [
           "/path/to/regulus/REPORT/mcp_server/regulus_es_mcp.py"
         ],
         "env": {
           "ES_URL": "https://username:password@your-es-host.amazonaws.com"
         }
       }
     }
   }
   ```

   Note: ES_INDEX is hardcoded as `regulus-results-*` - no need to configure it.

3. **Use with Cline**

   Open Cline in VS Code and ask:
   - "List all benchmark batches"
   - "Search for DPU results with throughput over 300 Gbps"
   - "Compare the last two upload batches"

**Benefits of Cline:**
- ✅ Works on Linux, macOS, Windows
- ✅ Integrated into your development environment
- ✅ Can create code/scripts based on query results
- ✅ Free and open source

---

### Option C: MCP Inspector (Testing/Development)

For development and testing:

```bash
# Install MCP Inspector
npm install -g @modelcontextprotocol/inspector

# Run with your server
cd $REG_ROOT/REPORT/mcp_server
source .venv/bin/activate
export ES_URL='https://username:password@your-es-host.com'

mcp-inspector regulus_es_mcp.py
```

Opens an interactive web interface for testing all MCP tools.

Note: ES_INDEX is automatically set to `regulus-results-*` from `es_config.py`.

---

## Standalone CLI Usage (No MCP Client Required)

If you're on Linux or prefer command-line tools, you can use the standalone CLI wrapper without Claude Desktop.

### Option 1: Published Container Image (Easiest)

Use the pre-built container image without cloning the repository:

```bash
# List all batches
docker run --rm \
  -e ES_URL='https://username:password@your-es-host.com' \
  ghcr.io/regulus/es-cli:latest \
  list-batches

# Search benchmarks
docker run --rm \
  -e ES_URL='https://username:password@your-es-host.com' \
  ghcr.io/regulus/es-cli:latest \
  search --benchmark uperf --size 10

# Get batch details
docker run --rm \
  -e ES_URL='https://username:password@your-es-host.com' \
  ghcr.io/regulus/es-cli:latest \
  batch-info <batch-id>

# Show statistics
docker run --rm \
  -e ES_URL='https://username:password@your-es-host.com' \
  ghcr.io/regulus/es-cli:latest \
  stats
```

**Create a shell alias for convenience:**
```bash
# Add to ~/.bashrc or ~/.zshrc
alias regulus='docker run --rm -e ES_URL="https://user:pass@host.com" ghcr.io/regulus/es-cli:latest'

# Then use it simply:
regulus list-batches
regulus search --benchmark uperf
```

**Notes:**
- Container image includes all dependencies
- ES_INDEX is hardcoded as `regulus-results-*` (no configuration needed)
- Only ES_URL credentials are required
- Works on Linux, macOS, Windows with Docker/Podman

### Option 2: Build Locally (Recommended for Development)

The easiest way to use the CLI is through the containerized version (requires podman or docker):

```bash
cd $REG_ROOT/REPORT/build_report/mcp_server

# The build_and_run.sh script handles everything
# On first run, it builds the image automatically

# List all batches
./build_and_run.sh list-batches

# Get batch details
./build_and_run.sh batch-info f2c533ef-b020-473e-babf-b81371e8147b

# Search benchmarks
./build_and_run.sh search --benchmark uperf --model OVNK --nic E810
./build_and_run.sh search --min-throughput 90 --size 20

# Compare two batches
./build_and_run.sh compare batch1-uuid batch2-uuid

# Delete a batch (with confirmation)
./build_and_run.sh delete batch-uuid
./build_and_run.sh delete batch-uuid --yes  # Skip confirmation

# Show index statistics
./build_and_run.sh stats

# Show help
./build_and_run.sh --help
```

**Override ES connection:**
```bash
export ES_URL='https://admin:password@other-es-host.com'
./build_and_run.sh list-batches
```

Note: ES_INDEX cannot be overridden - it's hardcoded as `regulus-results-*` in `es_config.py`.

### Option 3: Direct Python (Requires Python 3.10+)

If you prefer to run directly with Python:

```bash
cd $REG_ROOT/REPORT/mcp_server

# Create venv with Python 3.11+ (REQUIRED)
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Set environment variable (ES_INDEX is hardcoded)
export ES_URL='https://admin:password@your-es-host.com'

# Run commands
./es_cli.py list-batches
./es_cli.py batch-info <batch-id>
./es_cli.py search --benchmark uperf
./es_cli.py stats
```

### Testing with MCP Inspector

You can also test the MCP server interactively:

```bash
./test_mcp.sh
# This opens an interactive inspector to test MCP tools
```

## Usage Examples with Claude Desktop

Once configured with Claude Desktop, you can interact with Claude naturally:

### List Batches
```
"Show me all upload batches in ElasticSearch"
```

### Get Batch Details
```
"What's in batch f2c533ef-b020-473e-babf-b81371e8147b?"
```

### Search Benchmarks
```
"Find all uperf benchmarks with OVNK model and E810 NIC"
"Show me benchmarks with throughput over 90 Gbps"
```

### Compare Batches
```
"Compare performance between batch abc-123 and batch def-456"
```

### Delete Bad Upload
```
"Delete batch f2c533ef-b020-473e-babf-b81371e8147b"
```
(Claude will ask for confirmation)

### Get Statistics
```
"Show me statistics about the regulus index"
```

## Security Considerations

1. **Credentials in Config** - The `claude_desktop_config.json` contains your ES credentials. Ensure this file has appropriate permissions:
   ```bash
   chmod 600 ~/.config/Claude/claude_desktop_config.json
   ```

2. **Delete Operations** - The `delete_batch` tool requires explicit confirmation ("yes") to prevent accidental deletions.

3. **Network Access** - The MCP server makes direct HTTP requests to your ElasticSearch instance. Ensure network connectivity and firewall rules allow this.

## Troubleshooting

### Server Not Showing in Claude Desktop

1. Check the config file syntax (valid JSON)
2. Ensure absolute paths are correct
3. Verify Python virtual environment exists and uses Python 3.11+
4. Restart Claude Desktop
5. Check Claude Desktop logs:
   - macOS: `~/Library/Logs/Claude/`
   - Linux: `~/.config/Claude/logs/`

### Python Version Errors

**Error**: `Could not find a version that satisfies the requirement fastmcp`

**Solution**: You're using Python 3.6-3.10. You **must** use Python 3.11 or higher.

```bash
# Check your Python version
python3 --version

# If it's < 3.11, use python3.11 explicitly
python3.11 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**Error**: `ERROR: Could not find a version that satisfies the requirement mcp>=1.0.0`

**Solution**: Your requirements.txt is outdated. The `mcp>=1.0.0` package doesn't exist. Update requirements.txt to only contain:
```
httpx>=0.27.0
fastmcp>=0.1.0
```

### Connection Errors

1. Verify `ES_URL` is correct and accessible
2. ES_INDEX is hardcoded as `regulus-results-*` in `es_config.py` (no need to configure)
3. Test with curl:
   ```bash
   # Test with wildcard pattern
   curl "$ES_URL/regulus-results-*/_count"

   # List all regulus indices
   curl "$ES_URL/_cat/indices/regulus*?v"
   ```
4. Check network connectivity and credentials

**Common Index Issues:**
- **404 errors**: If you get 404 errors, the index may have rolled over. Always use `regulus-results-*` pattern.
- **Old index name**: If using `regulus-results` (no wildcard), update to `regulus-results-*`
- **No data found**: Check that indices exist with `curl "$ES_URL/_cat/indices/regulus*"`

### Tool Execution Errors

Enable debug logging by checking Claude Desktop logs. Common issues:
- ES query syntax errors (check ES version compatibility)
- Timeout on large queries (increase timeout in code if needed)
- Missing field mappings (ensure batch_id.keyword exists)

## Development

### Adding New Tools

1. Define a new async function with `@mcp.tool()` decorator
2. Add docstring describing the tool and its parameters
3. Implement ES query logic using `es_request()` helper
4. Return formatted string output
5. Test with `python regulus_es_mcp.py`

### Testing

```bash
# Manual test
python regulus_es_mcp.py

# The server will wait for stdio input
# Press Ctrl+C to exit
```

For full integration testing, use Claude Desktop or the MCP Inspector tool.

## References

- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- [MCP Python SDK](https://github.com/modelcontextprotocol/python-sdk)
- [FastMCP Framework](https://pypi.org/project/fastmcp/)
