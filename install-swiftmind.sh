#!/bin/bash

set -e

echo "🔧 Building SwiftMind in release mode..."
swift build -c release

BIN_PATH=".build/release/swiftmind"
INSTALL_PATH="/usr/local/bin"

echo "📦 Installing to $INSTALL_PATH..."
sudo cp "$BIN_PATH" "$INSTALL_PATH"
sudo chmod +x "$INSTALL_PATH/swiftmind"

echo "✅ Installed! You can now run:"
echo "   swiftmind --help"

///
📄 Как использовать
    1.    Сохрани файл как install-swiftmind.sh в корне проекта.
    2.    В терминале:
    
chmod +x install-swiftmind.sh
./install-swiftmind.sh

///
