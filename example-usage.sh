#!/bin/bash

# Example Usage of Vulnerability Scanner
# This script demonstrates how to use the vulnerability scanning tools

echo "🔍 SACRO-ML Vulnerability Scanning Example"
echo "=========================================="
echo

# Make the scanner executable
echo "1. Making scanner executable..."
chmod +x scan-vulnerabilities.sh
echo "✅ Done"
echo

# Show help
echo "2. Available commands:"
./scan-vulnerabilities.sh help
echo

# Install tools
echo "3. Installing Grype and Syft..."
./scan-vulnerabilities.sh install
echo

# Run a basic directory scan (with warnings resolved)
echo "4. Running basic directory scan (warnings resolved)..."
./scan-vulnerabilities.sh dir
echo

# Generate SBOM
echo "5. Generating SBOM..."
./scan-vulnerabilities.sh sbom
echo

# Run comprehensive scan (recommended)
echo "6. Running comprehensive scan (recommended approach)..."
./scan-vulnerabilities.sh comprehensive
echo

# Show results
echo "7. Scan results generated:"
if [ -d "scan-results" ]; then
    ls -la scan-results/
    echo
    
    # Show a sample of JSON results if available
    json_file=$(find scan-results -name "*.json" | head -1)
    if [ -n "$json_file" ]; then
        echo "📊 Sample JSON output (first 20 lines):"
        head -20 "$json_file"
        echo "..."
        echo
    fi
else
    echo "No scan-results directory found"
fi

# Compare scans
echo "8. Comparing different scan methods..."
./scan-vulnerabilities.sh compare
echo

# Show final summary
echo "🎉 Example completed!"
echo
echo "Next steps:"
echo "- Check scan-results/ directory for detailed reports"
echo "- Review .grype.yaml to customize scanning behavior"
echo "- Use GitHub Actions workflow for automated scanning"
echo "- Run './scan-vulnerabilities.sh comprehensive' regularly"
echo

# Cleanup demonstration files
echo "9. Cleaning up example files..."
./scan-vulnerabilities.sh cleanup
echo "✅ Cleanup done"