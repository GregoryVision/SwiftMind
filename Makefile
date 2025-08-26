//
//  Makefile
//  SwiftMind
//
//  Created by Gregory Tolkachev on 20.08.2025.
//

# ========== CONFIGURATION ==========

NAME = swiftmind
MODEL = codellama:7b-instruct

BIN_PATH = .build/release/$(NAME)
INSTALL_PATH = /usr/local/bin/$(NAME)

# ========== COMMANDS ==========

.PHONY: all build install uninstall check-ollama install-model

all: build

## 🔨 Build the CLI tool in release mode
build:
    @echo "🔧 Building $(NAME) in release mode..."
    @swift build -c release

## 📦 Install the binary into /usr/local/bin
install: check-ollama install-model build
    @echo "📥 Installing to /usr/local/bin..."
    @sudo cp $(BIN_PATH) $(INSTALL_PATH)
    @sudo chmod +x $(INSTALL_PATH)
    @echo "✅ Installed! Run:"
    @echo "   $(NAME) --help"

## ❌ Uninstall the CLI tool
uninstall:
    @echo "🧹 Removing $(INSTALL_PATH)..."
    @sudo rm -f $(INSTALL_PATH)
    @echo "✅ Uninstalled."

## 🧪 Check if Ollama is installed
check-ollama:
    @command -v ollama >/dev/null 2>&1 || { \
        echo "❌ Ollama is not installed."; \
        echo "Please install it from https://ollama.com/download or via Homebrew:"; \
        echo "   brew install ollama"; \
        exit 1; \
    }

## ⬇️ Pull the required model if not present
install-model:
    @ollama list | grep -q "$(MODEL)" || { \
        echo "📦 Pulling model $(MODEL)..."; \
        ollama pull $(MODEL); \
    }
