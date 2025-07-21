#!/bin/bash

# Copy default config
CONFIG_TEMPLATE="SwiftMind/Resources/ConfigTemplate.plist"
TARGET_CONFIG="swiftmind.plist"

if [ ! -f "$TARGET_CONFIG" ]; then
  echo "📝 No config found. Copying default config to current directory..."
  cp "$CONFIG_TEMPLATE" "$TARGET_CONFIG"
  echo "✅ Config file created at ./$TARGET_CONFIG"
else
  echo "⚠️ Config file already exists. Skipping creation."
fi
