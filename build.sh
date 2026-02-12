#!/usr/bin/env bash
# B2M - Build script with git clone automation
# Usage: ./build.sh [branch] [target]

set -e

REPO_URL="https://github.com/Sarthak-likely/b2m.git"
REPO_DIR="b2m"
BRANCH="${1:-main}"
TARGET="${2:-all}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  B2M - Bytes to MIDI Converter - Build Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check for git
if ! command -v git >/dev/null 2>&1; then
    echo -e "${RED}Error: git is not installed${NC}"
    echo "Please install git first:"
    echo "  Termux: pkg install git"
    echo "  Linux:  sudo apt install git"
    exit 1
fi

# Check for make
if ! command -v make >/dev/null 2>&1; then
    echo -e "${RED}Error: make is not installed${NC}"
    echo "Please install make first:"
    echo "  Termux: pkg install make"
    echo "  Linux:  sudo apt install build-essential"
    exit 1
fi

# Clone or pull repository
if [ -d "$REPO_DIR" ]; then
    echo -e "${YELLOW}Repository exists. Updating...${NC}"
    cd "$REPO_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
    cd ..
else
    echo -e "${GREEN}Cloning repository...${NC}"
    git clone --branch "$BRANCH" "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

# Show build info
echo ""
echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
echo -e "Repository: ${GREEN}$REPO_URL${NC}"
echo -e "Branch:     ${GREEN}$BRANCH${NC}"
echo -e "Target:     ${GREEN}$TARGET${NC}"
echo -e "Commit:     ${GREEN}$(git rev-parse --short HEAD)${NC}"
echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
echo ""

# Show device info
echo -e "${YELLOW}System Information:${NC}"
echo "  Hostname:   $(uname -n)"
echo "  OS:         $(uname -o 2>/dev/null || echo 'Unknown')"
echo "  Kernel:     $(uname -r)"
echo "  Architecture: $(uname -m)"
if command -v termux-info >/dev/null 2>&1; then
    echo "  Environment: Termux"
fi
echo ""

# Build
echo -e "${GREEN}Building with target: $TARGET${NC}"
echo ""

if [ "$TARGET" = "all" ]; then
    make
elif [ "$TARGET" = "install" ]; then
    make && make install
elif [ "$TARGET" = "test" ]; then
    make && make test
else
    make "$TARGET"
fi

# Show result
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Build successful!${NC}"
    
    if [ -f "b2m" ]; then
        BINARY_SIZE=$(wc -c < b2m | numfmt --to=iec 2>/dev/null || echo "$(wc -c < b2m) bytes")
        echo -e "  Binary: ./b2m ($BINARY_SIZE)"
    fi
    
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
    echo -e "${GREEN}Next steps:${NC}"
    echo "  1. Run: ./b2m --help"
    echo "  2. Install: sudo make install"
    echo "  3. Test: make test"
    echo -e "${BLUE}───────────────────────────────────────────────────────────${NC}"
else
    echo ""
    echo -e "${RED}✗ Build failed${NC}"
    exit 1
fi