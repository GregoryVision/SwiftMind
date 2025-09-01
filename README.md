# SwiftMind 🧠

**AI-powered CLI toolkit for Swift developers** — generate unit tests, documentation, reviews, and explanations for your Swift code using [Ollama](https://ollama.com/) and local LLMs.

SwiftMind helps you stay productive by automating boilerplate and providing code insights directly from the command line.

---

## ✨ Features

- ✅ **Generate XCTest tests** for individual functions 
- ✅ **Insert documentation** comments (`///`) directly into source code  
- ✅ **Perform code reviews** on selected functions, including inline `// REVIEW:` feedback  
- ✅ **Explain functions** in plain English for learning or onboarding  
- ✅ **Configurable** via `swiftmind.plist` (model, retries, directories, etc.)  
- ✅ Works entirely **locally** with [Ollama](https://ollama.com/), no cloud dependency  

---

## 🛠 Compatibility

- Swift toolchain: **5.10 or newer** (tested on 6.0.2)  
- SwiftSyntax: **510.x**  
  
SwiftSyntax 600.x (Swift 6 APIs) is planned but not required yet.

---

## ⚙️ Requirements

1. **Install Ollama**  
   - [Download from ollama.com](https://ollama.com/download)  
   - Or via Homebrew:  

     ```bash
     brew install ollama
     ```

2. **Pull a model** (default: `qwen2.5-coder:14b`)  

   ```bash
   ollama pull qwen2.5-coder:14b
   ```

---

## 🚀 Installation

Clone the repo and use `make install`:

```bash
git clone https://github.com/your-name/SwiftMind.git
cd SwiftMind
make install
```

This will:
- Build in release mode
- Install the binary into `/usr/local/bin/swiftmind` (override with `make PREFIX=$HOME/.local install`)
- Pull the required Ollama model if missing

Uninstall:

```bash
make uninstall
```

---

## 🖥 Usage

View all commands:

```bash
swiftmind --help
```

### Generate Tests

For a single function:

```bash
swiftmind test MyService.swift --functions doSomething
```

With additional context files:

```bash
swiftmind test MyService.swift --functions doSomething --context ./Mocks.swift
```

### Insert Documentation

```bash
swiftmind insert-docs MyService.swift doSomething
```

### Review Code

```bash
swiftmind review MyService.swift doSomething
```

### Explain a Function

```bash
swiftmind explain MyService.swift doSomething
```

### Init Config

```bash
swiftmind init
```

Creates `swiftmind.plist` in the current directory (override with `--path`).

---

## ⚙️ Configuration

SwiftMind loads settings from `swiftmind.plist`. Example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>defaultModel</key>
  <string>qwen2.5-coder:14b</string>
  <key>promptMaxLength</key>
  <integer>50000</integer>
  <key>testsDirectory</key>
  <string>GeneratedTests</string>
  <key>documentationDeclarations</key>
  <array>
    <string>FunctionDeclSyntax</string>
  </array>
</dict>
</plist>
```

---

## 🧪 Development

Build locally:

```bash
make build
```

Run checks:

```bash
make doctor
```

---

## 🤝 Contributing
See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🗺 Roadmap

- [x] Generate tests for individual functions
- [x] Generate tests for entire files
- [x] Insert documentation comments (`///`)
- [x] Inline code reviews with `// REVIEW:` blocks
- [x] Single-function explanations
- [x] Config via `swiftmind.plist`

### Planned
- [ ] **Xcode Extensions** for tighter IDE integration
- [ ] **`fix` command** — automatically fix common bugs and optimize code (within model capability)
- [ ] **Lightweight context algorithms** for commands (smart file selection & summarization)
- [ ] **Migration to newer local LLMs** as they become available
- [ ] Possible **prompt optimizations** (if models regress or require tuning)
- [ ] Support SwiftSyntax 600.x (Swift 6 toolchain)

### Ideas
- [ ] More documentation styles (brief, detailed with examples)
- [ ] Support for additional declaration kinds (properties, typealiases)
- [ ] Parallel test generation (when models/backends allow)
- [ ] Configurable global prompt templates
- [ ] Test coverage suggestions based on existing XCTest files
- [ ] Export results in Markdown/HTML for reports

---

## 📜 License

MIT License — feel free to use and contribute.
