# Publishing Guide

This guide covers how to publish and release new versions of Hanif CLI.

## Pre-Release Checklist

- [ ] All tests pass (`npm test`)
- [ ] Linting passes (`npm run lint`)
- [ ] Documentation is up to date
- [ ] CHANGELOG.md is updated
- [ ] Version numbers are updated
- [ ] Example commands work correctly
- [ ] Manual testing completed

## Version Numbering

Hanif CLI follows [Semantic Versioning](https://semver.org/):

- **MAJOR** (1.0.0): Breaking changes
- **MINOR** (0.1.0): New features, backwards compatible
- **PATCH** (0.0.1): Bug fixes, backwards compatible

### Version Checklist

Update version in these files:

1. `package.json` - "version" field
2. `bin/hanif` - VERSION variable
3. `hanif-cli.rb` - version and url fields
4. `README.md` - badges and installation instructions
5. `CHANGELOG.md` - new version section

## Publishing to npm

### Prerequisites

```bash
# Login to npm (first time only)
npm login

# Verify you're logged in
npm whoami
```

### Publishing Steps

1. **Update Version**

```bash
# Patch release (1.0.0 → 1.0.1)
npm version patch

# Minor release (1.0.0 → 1.1.0)
npm version minor

# Major release (1.0.0 → 2.0.0)
npm version major
```

This automatically:
- Updates package.json
- Creates a git commit
- Creates a git tag

2. **Update Other Files**

```bash
# Update bin/hanif
vim bin/hanif
# Change: VERSION="1.0.1"

# Update Homebrew formula
vim hanif-cli.rb
# Change: version "1.0.1"

# Commit changes
git add .
git commit -m "chore: update version to 1.0.1"
```

3. **Test Package**

```bash
# Dry run to see what will be published
npm publish --dry-run

# Check package contents
npm pack
tar -tzf hanif-cli-1.0.1.tgz
rm hanif-cli-1.0.1.tgz
```

4. **Publish**

```bash
# Publish to npm
npm publish

# Verify
npm view hanif-cli
```

5. **Push to Git**

```bash
# Push commits and tags
git push origin main
git push origin --tags
```

### Troubleshooting npm Publish

**Error: Package name already exists**
- Update package name in package.json (e.g., @yourusername/hanif-cli)

**Error: You do not have permission**
- Verify you're logged in: `npm whoami`
- Check package ownership: `npm owner ls hanif-cli`

**Error: Version already published**
- Increment version: `npm version patch`

## Publishing to Homebrew

### Prerequisites

- GitHub repository is public
- Release is tagged in git
- Tarball is available at GitHub releases

### Steps

1. **Create GitHub Release**

```bash
# Tag the release
git tag -a v1.0.1 -m "Release version 1.0.1"
git push origin v1.0.1
```

2. **Generate Tarball Checksum**

```bash
# Download release tarball
curl -L https://github.com/yourusername/hanif-cli-tools/archive/v1.0.1.tar.gz -o hanif-cli-1.0.1.tar.gz

# Generate SHA256
shasum -a 256 hanif-cli-1.0.1.tar.gz

# Copy the hash (e.g., abc123def456...)
```

3. **Update Homebrew Formula**

```ruby
# hanif-cli.rb
class HanifCli < Formula
  desc "Personal productivity CLI tool"
  homepage "https://github.com/yourusername/hanif-cli-tools"
  url "https://github.com/yourusername/hanif-cli-tools/archive/v1.0.1.tar.gz"
  sha256 "abc123def456..."  # Paste checksum here
  license "MIT"
  version "1.0.1"
  
  # ... rest of formula
end
```

4. **Test Formula Locally**

```bash
# Install from local formula
brew install --build-from-source ./hanif-cli.rb

# Test the formula
brew test hanif-cli

# Verify installation
hanif version

# Uninstall test
brew uninstall hanif-cli
```

5. **Submit to Homebrew Tap**

Option A: Own Homebrew Tap (Recommended for personal tools)

```bash
# Create homebrew-tap repository
# Repository name must be: homebrew-hanif

# Add formula
cp hanif-cli.rb /path/to/homebrew-hanif/Formula/

# Commit and push
cd /path/to/homebrew-hanif
git add Formula/hanif-cli.rb
git commit -m "hanif-cli: release 1.0.1"
git push origin main

# Users install with:
# brew tap yourusername/hanif
# brew install hanif-cli
```

Option B: Submit to Homebrew Core (For popular tools)

```bash
# Fork homebrew-core
# Add formula to Formula/
# Submit pull request

# See: https://docs.brew.sh/How-To-Open-a-Homebrew-Pull-Request
```

### Updating Homebrew Formula

For subsequent releases:

```bash
# Update version and sha256
vim hanif-cli.rb

# Test locally
brew reinstall --build-from-source ./hanif-cli.rb
brew test hanif-cli

# Push to tap
cd /path/to/homebrew-hanif
git add Formula/hanif-cli.rb
git commit -m "hanif-cli: release 1.0.2"
git push origin main
```

## GitHub Releases

### Create Release

1. Go to GitHub repository
2. Click "Releases" → "Draft a new release"
3. Choose tag (e.g., v1.0.1)
4. Release title: "v1.0.1"
5. Description: Copy from CHANGELOG.md
6. Attach binaries (if any)
7. Click "Publish release"

### Automated Releases (GitHub Actions)

Create `.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Node
        uses: actions/setup-node@v2
        with:
          node-version: '16'
          registry-url: 'https://registry.npmjs.org'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run tests
        run: npm test
      
      - name: Publish to npm
        run: npm publish
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
      
      - name: Create GitHub Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ github.ref }}
          release_name: Release ${{ github.ref }}
          body_path: CHANGELOG.md
          draft: false
          prerelease: false
```

## Direct Installation Script

The `install.sh` script automatically pulls from the main branch.

Users install with:

```bash
curl -fsSL https://raw.githubusercontent.com/yourusername/hanif-cli-tools/main/install.sh | bash
```

### Update Installation Script

When releasing, ensure install.sh:
- Points to correct repository
- Has correct default version
- Installation paths are correct

## CHANGELOG Format

Use [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Feature in development

### Changed
- Improvements

### Fixed
- Bug fixes

## [1.0.1] - 2024-01-15

### Fixed
- Fixed branch naming issue with special characters
- Corrected help text formatting

## [1.0.0] - 2024-01-01

### Added
- Initial release
- Git helper commands
- Smart branch creation
- Automatic branch cleanup
- Rebase workflows

[Unreleased]: https://github.com/user/repo/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/user/repo/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/user/repo/releases/tag/v1.0.0
```

## Release Process

### Full Release Workflow

```bash
# 1. Ensure main branch is up to date
git checkout main
git pull origin main

# 2. Run full test suite
npm test
npm run lint

# 3. Update CHANGELOG.md
vim CHANGELOG.md
# Move items from [Unreleased] to new version section

# 4. Update version
npm version minor  # or patch, major

# 5. Update other version references
vim bin/hanif        # Update VERSION
vim hanif-cli.rb     # Update version and url
git add .
git commit --amend --no-edit

# 6. Create and test package
npm pack
tar -tzf hanif-cli-*.tgz
rm hanif-cli-*.tgz

# 7. Tag and push
git push origin main
git push origin --tags

# 8. Publish to npm
npm publish

# 9. Create GitHub release (manual or automated)

# 10. Update Homebrew formula
# Generate checksum
curl -L https://github.com/user/repo/archive/v1.1.0.tar.gz -o temp.tar.gz
shasum -a 256 temp.tar.gz
rm temp.tar.gz

# Update formula
vim hanif-cli.rb
# Update sha256

# Push to tap
cd /path/to/homebrew-hanif
git add Formula/hanif-cli.rb
git commit -m "hanif-cli: release 1.1.0"
git push origin main

# 11. Announce release
# - Update README.md if needed
# - Post in discussions
# - Tweet/share if applicable
```

## Versioning Examples

### Patch Release (Bug Fix)

Changes:
- Fixed typo in help text
- Corrected error message

Version: 1.0.0 → 1.0.1

```bash
npm version patch
# Update other files
git push origin main --tags
npm publish
```

### Minor Release (New Feature)

Changes:
- Added new `hanif git sync` command
- Improved error handling

Version: 1.0.1 → 1.1.0

```bash
npm version minor
# Update other files
git push origin main --tags
npm publish
```

### Major Release (Breaking Change)

Changes:
- Changed command structure
- Removed deprecated commands
- New required dependencies

Version: 1.1.0 → 2.0.0

```bash
npm version major
# Update other files
# Update migration guide in docs
git push origin main --tags
npm publish
```

## Beta/Alpha Releases

For testing before official release:

```bash
# Publish beta
npm version prerelease --preid=beta
# Results in: 1.1.0-beta.0

npm publish --tag beta

# Users install with:
# npm install -g hanif-cli@beta

# After testing, publish as stable
npm version minor  # 1.1.0
npm publish
```

## Rollback

If you need to unpublish or rollback:

```bash
# Unpublish specific version (within 72 hours)
npm unpublish hanif-cli@1.0.1

# Deprecate version (preferred over unpublish)
npm deprecate hanif-cli@1.0.1 "Please use version 1.0.2"
```

## Post-Release

- [ ] Verify npm package: `npm view hanif-cli`
- [ ] Test installation: `npm install -g hanif-cli`
- [ ] Verify Homebrew: `brew install yourusername/hanif/hanif-cli`
- [ ] Test direct install: `curl ... | bash`
- [ ] Update documentation if needed
- [ ] Monitor for issues
- [ ] Respond to feedback

## Helpful Commands

```bash
# View current npm version
npm view hanif-cli version

# View all published versions
npm view hanif-cli versions

# Check package info
npm info hanif-cli

# List package contents
npm pack --dry-run

# Verify formula
brew audit --strict hanif-cli

# Bump version without publishing
npm version patch --no-git-tag-version
```

## Resources

- [npm Publishing Docs](https://docs.npmjs.com/cli/v8/commands/npm-publish)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
