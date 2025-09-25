#!/usr/bin/env bash
set -euo pipefail

echo "=== Vite + React -> GitHub Pages Setup ==="
echo "This script will:"
echo "  1) Create a Vite React app"
echo "  2) Initialize Git and push to your GitHub repo"
echo "  3) Configure gh-pages and deploy (branch: gh-pages)"
echo

read -rp "Project name (lowercase, no spaces) [learning_react]: " PROJECT_NAME
PROJECT_NAME=${PROJECT_NAME:-learning_react}

read -rp "GitHub repository URL (e.g., https://github.com/<user>/<repo>.git): " REPO_URL
if [[ -z "${REPO_URL}" ]]; then
  echo "Repository URL is required. Aborting."
  exit 1
fi

# Derive repository name from URL
REPO_NAME="${REPO_URL%.git}"
REPO_NAME="${REPO_NAME##*/}"

read -rp "Git user.name (for local commits): " GIT_NAME
read -rp "Git user.email (for local commits): " GIT_EMAIL

echo
echo "==> Summary"
echo "Project: ${PROJECT_NAME}"
echo "Repo URL: ${REPO_URL}"
echo "Repo name: ${REPO_NAME}"
echo "Git user.name: ${GIT_NAME}"
echo "Git user.email: ${GIT_EMAIL}"
echo

read -rp "Proceed? [y/N]: " CONFIRM
if [[ ! "${CONFIRM}" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 1
fi

# 1) Create Vite React app
echo
echo "==> Creating Vite React app..."
npm create vite@latest "${PROJECT_NAME}" -- --template react

cd "${PROJECT_NAME}"

echo
echo "==> Installing dependencies..."
npm install

# 2) Patch package.json scripts: add preview, predeploy, deploy
echo
echo "==> Updating package.json scripts (preview, predeploy, deploy)..."
node - <<'NODE'
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts.preview = "vite build && vite preview --host";
pkg.scripts.predeploy = "npm run build";
pkg.scripts.deploy = "gh-pages -d dist";
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + "\n");
console.log("package.json updated.");
NODE

# 3) Ensure vite.config.js has base: '/<repo>/'
echo
echo "==> Ensuring vite.config.js has base: '/${REPO_NAME}/' ..."
if [[ -f "vite.config.js" ]]; then
  # Insert base after 'defineConfig({' if not present; otherwise replace any existing base
  if grep -q "base:" vite.config.js; then
    # Replace existing base line
    # Use a portable sed approach that should work in GNU sed
    sed -i "s|base: *['\"][^'\"]*['\"]|base: '/${REPO_NAME}/'|g" vite.config.js
  else
    # Insert base line after first occurrence of defineConfig({
    awk -v repo="${REPO_NAME}" '
      BEGIN{inserted=0}
      {
        print $0
        if (!inserted && $0 ~ /defineConfig\s*\(\s*{/) {
          print "  base: \x27/" repo "/\x27,"
          inserted=1
        }
      }
    ' vite.config.js > vite.config.js.tmp && mv vite.config.js.tmp vite.config.js
  fi
else
  # Create a minimal vite.config.js
  cat > vite.config.js <<VITECFG
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  base: '/${REPO_NAME}/',
  plugins: [react()],
})
VITECFG
fi

# 4) Initialize Git, set config, initial commit, push
echo
echo "==> Initializing Git repository..."
git init
git config --global --add safe.directory "$(pwd)"
if [[ -n "${GIT_NAME}" ]]; then git config user.name "${GIT_NAME}"; fi
if [[ -n "${GIT_EMAIL}" ]]; then git config user.email "${GIT_EMAIL}"; fi

echo "==> Committing initial files..."
git add -A
git commit -m "initial commit"
git branch -M main
git remote add origin "${REPO_URL}" || git remote set-url origin "${REPO_URL}"
echo "==> Pushing to origin main (you may be prompted for username and a Personal Access Token as password)..."
git push -u origin main

# 5) Install gh-pages and deploy
echo
echo "==> Installing gh-pages..."
npm install gh-pages --save-dev

echo "==> Deploying to GitHub Pages (branch: gh-pages)..."
npm run deploy

cat <<NOTE

=========================================================
Deployment triggered.
Next steps (manual in GitHub UI):
- Open your repository on GitHub -> Settings -> Pages
- Select the 'gh-pages' branch (if not auto-selected) and save.
- After a minute or two, your site should be live at:
  https://<your-username>.github.io/${REPO_NAME}/
=========================================================

NOTE

echo "All done."
