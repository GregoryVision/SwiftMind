# ========== CONFIGURATION ==========
NAME        := swiftmind
MODEL       := qwen2.5-coder:14b

PREFIX      ?= /usr/local
BIN_PATH    := .build/release/$(NAME)
INSTALL_BIN := $(PREFIX)/bin/$(NAME)

CONFIG_SRC  := Resources/swiftmind/swiftmind.plist
CONFIG_DST  := swiftmind.plist

# ========== COMMANDS ==========

.PHONY: all build install uninstall doctor check-ollama install-model

all: build

## 🔨 Build the CLI tool in release mode
build:
	@echo "🔧 Building $(NAME) in release mode..."
	@swift build -c release

## 📦 Install the binary into $(PREFIX)/bin (override with: make PREFIX=$$HOME/.local install)
install: doctor check-ollama install-model build
	@echo "📥 Installing to $(INSTALL_BIN)..."
	@mkdir -p "$(PREFIX)/bin"
	@install -m 755 "$(BIN_PATH)" "$(INSTALL_BIN)"
	@echo "✅ Installed! Run:"
	@echo "   $(NAME) --help"

## ❌ Uninstall the CLI tool
uninstall:
	@echo "🧹 Removing $(INSTALL_BIN)..."
	@rm -f "$(INSTALL_BIN)"
	@echo "✅ Uninstalled."

## 🧪 Check tools
doctor:
	@command -v swift >/dev/null 2>&1 || { echo "❌ Swift not found"; exit 1; }
	@command -v git   >/dev/null 2>&1 || { echo "❌ git not found";   exit 1; }
	@echo "✅ Tooling OK"

## 🧪 Check if Ollama is installed
check-ollama:
	@command -v ollama >/dev/null 2>&1 || { \
		echo "❌ Ollama is not installed."; \
		echo "   Install: brew install ollama  (or from https://ollama.com/download)"; \
		exit 1; \
	}

## ⬇️ Pull the required model if not present
install-model:
	@ollama list | grep -q "$(MODEL)" || { \
		echo "📦 Pulling model $(MODEL)..."; \
		ollama pull $(MODEL); \
	}
