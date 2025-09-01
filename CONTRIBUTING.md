# Contributing to SwiftMind

First off — thank you for your interest in contributing! 🎉  
SwiftMind is an open-source project that thrives on community input and ideas.  

We use a **Trunk-Based Development** workflow:

---

## 🌳 Branching Model

- The `main` branch is always stable and deployable.
- All work happens in **short-lived feature branches**, for example:
  - `feature/add-insert-docs`
  - `fix/review-comments-crash`

---

## 🚀 How to Contribute

1. **Fork** the repository  
   ```bash
   git clone https://github.com/GregoryVision/SwiftMind.git
   cd SwiftMind
   ```

2. **Create a branch** for your work  
   ```bash
   git checkout -b feature/my-cool-feature
   ```

3. **Make your changes**  
   - Follow Swift style guidelines  
   - Ensure your code builds:  
     ```bash
     make build
     ```
   - Run tests (if applicable):  
     ```bash
     swift test
     ```

4. **Commit & push**  
   ```bash
   git commit -m "Add: description of your change"
   git push origin feature/my-cool-feature
   ```

5. **Open a Pull Request** to `main`  
   - Keep PRs focused and small  
   - Describe what was changed and why  

---

## 🏷 Releases

- Releases are cut from `main` using **git tags**.  
- Example:  
  ```bash
  git tag v0.1.0
  git push origin v0.1.0
  ```

GitHub will automatically pick up tags and display them in the **Releases** section.

---

## ✅ Code Style

- Prefer readability over cleverness.  
- Use `///` documentation comments where helpful.  
- Keep functions small and focused.  
- Run `swift format` if you use SwiftFormat locally.  

---

## 💡 Ideas & Issues

- Use GitHub Issues for bug reports and feature requests.  
- For big changes, open an Issue first to discuss before submitting a PR.  

---

Thanks for contributing 💜  
