//
//  README.md
//  SwiftMind
//
//  Created by Gregory Tolkachev on 20.08.2025.
//

## 🚀 Установка

### Вариант 1: через Makefile

## ⚙️ Requirements

1. **Install Ollama** (if not yet installed):
   - Recommended: [Download from ollama.com](https://ollama.com/download)
   - Or install via Homebrew:
     ```bash
     brew install ollama
     ```

2. **Run Ollama** (the daemon must be active):
   ```bash
   ollama run codellama:7b-instruct

```bash
git clone https://github.com/your-name/SwiftMind.git
cd SwiftMind
make install







# 1. Клонируй репозиторий
git clone https://github.com/your-username/SwiftMind.git
cd SwiftMind

# 2. Сделай скрипт исполняемым
chmod +x install-swiftmind.sh

# 3. Запусти установку (потребуется пароль)
./install-swiftmind.sh

# 4. Проверь установку
swiftmind --help


### How It Works

SwiftMind uses AI (LLM via Ollama) to generate unit tests for your Swift code.

The model is instructed to:
- Cover both positive and negative test cases
- Use `FileManager.temporaryDirectory` when needed
- Prefer behavior-driven tests over implementation details
- Return readable and idiomatic `XCTestCase` subclasses

You can customize the prompt or add context files for better results.

Example:
```bash
swiftmind test MyService.swift --functions doSomething --context ./Mocks.swift
