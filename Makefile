# OpenShift Build Data Multi-Version Toolset Makefile

# Force bash as shell for all commands
SHELL := /bin/bash

# Default target
.PHONY: help
help: ## Show this help message
	@echo "OpenShift Build Data Multi-Version Toolset"
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Check if required dependencies are installed
.PHONY: check-deps
check-deps: ## Check if all required dependencies are installed
	@echo "Checking dependencies..."
	@command -v bash >/dev/null 2>&1 || { echo "❌ bash is required but not installed."; exit 1; }
	@bash --version | head -n1 | awk '{if ($$4 < 4.0) {print "❌ bash 4.0+ is required. Current version: " $$4; exit 1} else {print "✅ bash: " $$4}}'
	@command -v git >/dev/null 2>&1 || { echo "❌ git is required but not installed."; exit 1; }
	@echo "✅ git: $$(git --version | awk '{print $$3}')"
	@command -v yq >/dev/null 2>&1 || { echo "❌ yq (v4.0+) is required but not installed."; exit 1; }
	@yq --version | grep -q "version v4\|version v[5-9]" || { echo "❌ yq v4.0+ is required. Current: $$(yq --version)"; exit 1; }
	@echo "✅ yq: $$(yq --version | awk '{print $$4}')"
	@command -v jq >/dev/null 2>&1 || { echo "❌ jq is required but not installed."; exit 1; }
	@echo "✅ jq: $$(jq --version)"
	@command -v gh >/dev/null 2>&1 || { echo "❌ gh (GitHub CLI) is required but not installed."; exit 1; }
	@echo "✅ gh: $$(gh --version | head -n1 | awk '{print $$3}')"
	@echo ""
	@echo "✅ All dependencies are installed!"

# Install dependencies on macOS
.PHONY: install-deps-macos
install-deps-macos: ## Install dependencies on macOS using Homebrew
	@echo "Installing dependencies on macOS..."
	@command -v brew >/dev/null 2>&1 || { echo "❌ Homebrew is required. Install from https://brew.sh"; exit 1; }
	@brew install git yq jq gh
	@echo "✅ Dependencies installed via Homebrew"

# Install dependencies on Ubuntu/Debian
.PHONY: install-deps-ubuntu
install-deps-ubuntu: ## Install dependencies on Ubuntu/Debian
	@echo "Installing dependencies on Ubuntu/Debian..."
	@sudo apt-get update
	@sudo apt-get install -y git jq
	@echo "Installing yq..."
	@sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
	@sudo chmod +x /usr/local/bin/yq
	@echo "Installing GitHub CLI..."
	@curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
	@echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
	@sudo apt-get update
	@sudo apt-get install -y gh
	@echo "✅ Dependencies installed"

# Install dependencies on RHEL/CentOS/Fedora
.PHONY: install-deps-rhel
install-deps-rhel: ## Install dependencies on RHEL/CentOS/Fedora
	@echo "Installing dependencies on RHEL/CentOS/Fedora..."
	@sudo dnf install -y git jq
	@echo "Installing yq..."
	@sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
	@sudo chmod +x /usr/local/bin/yq
	@echo "Installing GitHub CLI..."
	@sudo dnf install -y gh
	@echo "✅ Dependencies installed"

# Auto-detect OS and install dependencies
.PHONY: install-deps
install-deps: ## Auto-detect OS and install dependencies
	@echo "Auto-detecting operating system..."
	@if [[ "$$(uname)" == "Darwin" ]]; then \
		$(MAKE) install-deps-macos; \
	elif [[ -f /etc/debian_version ]]; then \
		$(MAKE) install-deps-ubuntu; \
	elif [[ -f /etc/redhat-release ]]; then \
		$(MAKE) install-deps-rhel; \
	else \
		echo "❌ Unsupported operating system. Please install dependencies manually:"; \
		echo "  - bash 4.0+"; \
		echo "  - git"; \
		echo "  - yq v4.0+ (https://github.com/mikefarah/yq)"; \
		echo "  - jq"; \
		echo "  - gh (GitHub CLI)"; \
		exit 1; \
	fi

# Setup personal configuration
.PHONY: setup-config
setup-config: ## Setup personal configuration (copy remotes.conf.example)
	@if [[ ! -f config/remotes.conf ]]; then \
		if [[ -f config/remotes.conf.example ]]; then \
			cp config/remotes.conf.example config/remotes.conf; \
			echo "✅ Created config/remotes.conf from template"; \
			echo "⚠️  Please edit config/remotes.conf with your GitHub account details"; \
		else \
			echo "❌ config/remotes.conf.example not found"; \
			exit 1; \
		fi; \
	else \
		echo "✅ config/remotes.conf already exists"; \
	fi

# Complete setup process
.PHONY: setup
setup: check-deps setup-config ## Complete setup process (check deps + config)
	@echo ""
	@echo "🎉 Setup complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Edit config/remotes.conf with your GitHub account details"
	@echo "2. Fork the upstream repository: https://github.com/openshift-eng/ocp-build-data"
	@echo "3. Initialize worktrees: ./tools/ocp-setup init"
	@echo ""
	@echo "For help: ./tools/ocp-setup --help"

# Validate tools are working
.PHONY: validate
validate: check-deps ## Validate that all tools are working correctly
	@echo "Validating toolset..."
	@./tools/ocp-setup --help >/dev/null || { echo "❌ ocp-setup not working"; exit 1; }
	@echo "✅ ocp-setup working"
	@./tools/ocp-diff --help >/dev/null || { echo "❌ ocp-diff not working"; exit 1; }
	@echo "✅ ocp-diff working"
	@./tools/ocp-view --help >/dev/null || { echo "❌ ocp-view not working"; exit 1; }
	@echo "✅ ocp-view working"
	@./tools/ocp-bulk --help >/dev/null || { echo "❌ ocp-bulk not working"; exit 1; }
	@echo "✅ ocp-bulk working"
	@./tools/ocp-hermetic --help >/dev/null || { echo "❌ ocp-hermetic not working"; exit 1; }
	@echo "✅ ocp-hermetic working"
	@echo ""
	@echo "✅ All tools validated successfully!"

# Clean up temporary files and worktrees
.PHONY: clean
clean: ## Clean up temporary files and worktrees  
	@echo "Cleaning up..."
	@find . -name "*.log" -delete 2>/dev/null || true
	@find . -name "*.tmp" -delete 2>/dev/null || true
	@echo "✅ Temporary files cleaned"
	@if [[ -d versions ]]; then \
		echo "⚠️  Worktrees found in versions/ directory"; \
		echo "   Run './tools/ocp-setup clean all' to remove all worktrees"; \
	fi

# Show current status
.PHONY: status
status: ## Show current toolset status
	@echo "OpenShift Build Data Multi-Version Toolset Status"
	@echo "================================================"
	@echo ""
	@echo "Dependencies:"
	@$(MAKE) check-deps 2>/dev/null && echo "" || echo ""
	@echo "Configuration:"
	@if [[ -f config/remotes.conf ]]; then \
		echo "✅ config/remotes.conf exists"; \
	else \
		echo "❌ config/remotes.conf missing (run 'make setup-config')"; \
	fi
	@echo ""
	@echo "Worktrees:"
	@if [[ -d versions ]]; then \
		echo "✅ versions/ directory exists"; \
		echo "   Active versions: $$(ls versions/ 2>/dev/null | tr '\n' ' ' || echo 'none')"; \
	else \
		echo "❌ No worktrees initialized (run './tools/ocp-setup init')"; \
	fi

# Local Development and Testing
# =============================

# Linting targets
.PHONY: lint-shell
lint-shell: ## Run ShellCheck on all shell scripts
	@echo "Running ShellCheck on shell scripts..."
	@command -v shellcheck >/dev/null 2>&1 || { echo "❌ shellcheck not installed. Install with: apt-get install shellcheck / brew install shellcheck"; exit 1; }
	@find tools/ -name "*.sh" -o -path "tools/ocp-*" | xargs shellcheck --severity=warning
	@echo "✅ ShellCheck passed"

.PHONY: lint-markdown
lint-markdown: ## Run markdownlint on all markdown files
	@echo "Running markdownlint on markdown files..."
	@command -v markdownlint >/dev/null 2>&1 || { echo "❌ markdownlint not installed. Install with: npm install -g markdownlint-cli"; exit 1; }
	@markdownlint README.md CONTRIBUTING.md
	@echo "✅ Markdown linting passed"

.PHONY: lint
lint: lint-shell lint-markdown ## Run all linting checks
	@echo "✅ All linting checks passed"

# Additional validation targets
.PHONY: validate-tools
validate-tools: ## Test that all tools show help
	@echo "Validating all tools show help..."
	@for tool in tools/ocp-*; do echo "Testing $$tool --help"; $$tool --help >/dev/null 2>&1 || exit 1; done
	@echo "✅ All tools validated"

# Pre-commit checks
.PHONY: pre-commit
pre-commit: lint ## Run all checks before committing
	@echo "✅ All pre-commit checks passed"