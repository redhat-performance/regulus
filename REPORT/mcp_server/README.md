# Regulus ElasticSearch MCP Server

Model Context Protocol (MCP) server for interacting with Regulus benchmark data in ElasticSearch through Claude Desktop or other MCP clients.

## What is MCP?

MCP (Model Context Protocol) allows Claude to directly interact with your ElasticSearch data through specialized tools. Instead of running makefile commands manually, you can ask Claude to query, analyze, and manage your benchmark results in natural language.

## Features

The Regulus ES MCP server provides these tools:

1. **list_batches** - List all upload batches with document counts
2. **get_batch_info** - Get detailed information about a specific batch
3. **search_benchmarks** - Search for benchmark results with filters (benchmark type, model, NIC, throughput)
4. **compare_batches** - Compare performance between two upload batches
5. **delete_batch** - Delete all documents in a batch (with confirmation)
6. **get_index_stats** - Get overall index statistics

## Installation

### Prerequisites

- Python 3.10 or higher
- Access to your ElasticSearch instance

### Setup

1. **Create a virtual environment:**

```bash
cd $REG_ROOT/REPORT/build_report/mcp_server
python3 -m venv .venv
source .venv/bin/activate
```

2. **Install dependencies:**

```bash
pip install "mcp[cli]" httpx
```

3. **Test the server:**

```bash
# Set your ES connection
export ES_URL='https://admin:password@your-es-host.com'
export ES_INDEX='regulus-results'

# Test run
python regulus_es_mcp.py
```

The server should start without errors (it will wait for stdio input from an MCP client).

## Configuration for Claude Desktop

Add the MCP server to your Claude Desktop configuration file:

**Location:**
- macOS: `~/Library/Application Support/Claude/claude_desktop_config.json`
- Linux: `~/.config/Claude/claude_desktop_config.json`

**Configuration:**

```json
{
  "mcpServers": {
    "regulus-elasticsearch": {
      "command": "/home/hnhan/CLAUDE-PROJOECTS/report-proj/regulus/REPORT/build_report/mcp_server/.venv/bin/python",
      "args": [
        "/home/hnhan/CLAUDE-PROJOECTS/report-proj/regulus/REPORT/build_report/mcp_server/regulus_es_mcp.py"
      ],
      "env": {
        "ES_URL": "https://admin:nKNQ9=vw_bwaSy1@search-perfscale-pro-wxrjvmobqs7gsyi3xvxkqmn7am.us-west-2.es.amazonaws.com",
        "ES_INDEX": "regulus-results"
      }
    }
  }
}
```

**Important:**
- Use absolute paths for both the Python interpreter and the script
- Include your ES credentials in the `ES_URL`
- Restart Claude Desktop after editing the config

## Standalone CLI Usage (Linux/Terminal)

If you're on Linux or prefer command-line tools, you can use the standalone CLI wrapper without Claude Desktop.

### Option 1: Containerized (Recommended)

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
export ES_INDEX='other-index'
./build_and_run.sh list-batches
```

### Option 2: Direct Python (Requires Python 3.10+)

If you prefer to run directly with Python:

```bash
cd $REG_ROOT/REPORT/build_report/mcp_server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Set environment variables
export ES_URL='https://admin:password@your-es-host.com'
export ES_INDEX='regulus-results'

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
3. Verify Python virtual environment exists
4. Restart Claude Desktop
5. Check Claude Desktop logs:
   - macOS: `~/Library/Logs/Claude/`
   - Linux: `~/.config/Claude/logs/`

### Connection Errors

1. Verify `ES_URL` is correct and accessible
2. Test with curl:
   ```bash
   curl "$ES_URL/regulus-results/_count"
   ```
3. Check network connectivity and credentials

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
