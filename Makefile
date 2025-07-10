# Makefile for SACRO-ML Vulnerability Scanning
# Provides easy access to vulnerability scanning operations

.PHONY: help install scan scan-comprehensive scan-dir scan-venv scan-compare security-check clean

# Default target
help: ## Show this help message
	@echo "SACRO-ML Vulnerability Scanning Commands"
	@echo "========================================"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Quick start: make scan"

install: ## Install Grype and Syft vulnerability scanning tools
	@echo "Installing vulnerability scanning tools..."
	@chmod +x scan-vulnerabilities.sh
	@./scan-vulnerabilities.sh install

scan: install ## Run comprehensive vulnerability scan (recommended)
	@echo "Running comprehensive vulnerability scan..."
	@./scan-vulnerabilities.sh comprehensive

scan-dir: install ## Scan current directory with warnings resolved
	@echo "Scanning current directory..."
	@./scan-vulnerabilities.sh dir

scan-venv: install ## Scan Python virtual environment (.venv)
	@echo "Scanning virtual environment..."
	@./scan-vulnerabilities.sh venv

scan-compare: install ## Compare directory scan vs SBOM scan
	@echo "Comparing scan methods..."
	@./scan-vulnerabilities.sh compare

security-check: scan ## Alias for comprehensive scan
	@echo "Security check completed"

sbom: install ## Generate Software Bill of Materials (SBOM)
	@echo "Generating SBOM..."
	@./scan-vulnerabilities.sh sbom

example: ## Run example demonstration
	@echo "Running vulnerability scanning example..."
	@chmod +x example-usage.sh
	@./example-usage.sh

clean: ## Clean up temporary files and scan results
	@echo "Cleaning up..."
	@./scan-vulnerabilities.sh cleanup
	@rm -rf scan-results/
	@rm -f sacroml-sbom.spdx.json
	@echo "Cleanup completed"

clean-all: clean ## Clean up everything including installed tools
	@echo "Cleaning up everything..."
	@rm -rf bin/
	@echo "All files cleaned up"

# Development targets
dev-setup: install ## Set up development environment with security tools
	@echo "Setting up development environment..."
	@pip install --upgrade pip
	@pip install -e .
	@echo "Development environment ready"

ci-scan: ## Run scan suitable for CI/CD (with JSON output)
	@echo "Running CI/CD vulnerability scan..."
	@chmod +x scan-vulnerabilities.sh
	@./scan-vulnerabilities.sh install
	@./scan-vulnerabilities.sh comprehensive
	@echo "CI scan completed - check scan-results/ for artifacts"

# Show scan results
show-results: ## Display recent scan results
	@echo "Recent vulnerability scan results:"
	@echo "=================================="
	@if [ -d "scan-results" ]; then \
		echo "Generated files:"; \
		ls -la scan-results/; \
		echo; \
		json_file=$$(find scan-results -name "*.json" | head -1); \
		if [ -n "$$json_file" ]; then \
			echo "Summary from $$json_file:"; \
			if command -v jq >/dev/null 2>&1; then \
				jq -r '.matches | length' "$$json_file" | xargs echo "Vulnerabilities found:"; \
			else \
				echo "Install 'jq' for detailed JSON parsing"; \
			fi; \
		fi; \
	else \
		echo "No scan results found. Run 'make scan' first."; \
	fi

# Check if vulnerable packages are present
check-torch: ## Check specifically for torch vulnerabilities
	@echo "Checking for torch package vulnerabilities..."
	@if [ -d "scan-results" ]; then \
		json_file=$$(find scan-results -name "*.json" | head -1); \
		if [ -n "$$json_file" ]; then \
			if command -v jq >/dev/null 2>&1; then \
				jq -r '.matches[] | select(.artifact.name | contains("torch")) | .vulnerability.id + " (" + .vulnerability.severity + ")"' "$$json_file" 2>/dev/null || echo "No torch vulnerabilities found in scan results"; \
			else \
				grep -i torch "$$json_file" || echo "No torch references found"; \
			fi; \
		else \
			echo "No JSON results found"; \
		fi; \
	else \
		echo "No scan results found. Run 'make scan' first."; \
	fi

# Status check
status: ## Show current vulnerability scanning status
	@echo "Vulnerability Scanning Status"
	@echo "============================="
	@echo -n "Grype installed: "
	@if [ -f "bin/grype" ]; then echo "✅ Yes (bin/grype)"; else echo "❌ No"; fi
	@echo -n "Syft installed: "
	@if [ -f "bin/syft" ]; then echo "✅ Yes (bin/syft)"; else echo "❌ No"; fi
	@echo -n "SBOM generated: "
	@if [ -f "sacroml-sbom.spdx.json" ]; then echo "✅ Yes"; else echo "❌ No"; fi
	@echo -n "Scan results: "
	@if [ -d "scan-results" ] && [ "$(shell ls -A scan-results 2>/dev/null)" ]; then echo "✅ Available"; else echo "❌ None"; fi
	@echo -n "Configuration: "
	@if [ -f ".grype.yaml" ]; then echo "✅ Present"; else echo "❌ Missing"; fi