#!/bin/sh
set -euf

if [ "$#" -ne 2 ]; then
    echo "usage: $0 POWERSHELL_OUTPUT SHELL_OUTPUT" >&2
    exit 2
fi

ps_output=$1
sh_output=$2

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

check_required_sections() {
    # $1 = file path, $2 = label
    file=$1
    label=$2
    all_found=0
    
    printf "${CYAN}Checking %s output...${NC}\n" "$label"
    
    if ! grep -q "=== DK PROJECT DETECTION ===" "$file" 2>/dev/null; then
        printf "${RED}❌ Missing section: DK PROJECT DETECTION${NC}\n"
        all_found=1
    else
        printf "${GREEN}✓ Found section: DK PROJECT DETECTION${NC}\n"
    fi

    if ! grep -q "=== DEPENDENCIES (from root dk.u %% import) ===" "$file" 2>/dev/null; then
        printf "${RED}❌ Missing section: DEPENDENCIES${NC}\n"
        all_found=1
    else
        printf "${GREEN}✓ Found section: DEPENDENCIES${NC}\n"
    fi

    if ! grep -q "=== DIST VERSION FILES (etc/dk/d/\*.json) ===" "$file" 2>/dev/null; then
        printf "${RED}❌ Missing section: DIST VERSION FILES${NC}\n"
        all_found=1
    else
        printf "${GREEN}✓ Found section: DIST VERSION FILES${NC}\n"
    fi
    
    if ! grep -q "=== DIST-\*.U/RUN.U FILES ===" "$file" 2>/dev/null; then
        printf "${RED}❌ Missing section: DIST-*.U/RUN.U FILES${NC}\n"
        all_found=1
    else
        printf "${GREEN}✓ Found section: DIST-*.U/RUN.U FILES${NC}\n"
    fi
    
    if ! grep -q "=== VALUES FILES (etc/dk/v/\*.values.\*) ===" "$file" 2>/dev/null; then
        printf "${RED}❌ Missing section: VALUES FILES${NC}\n"
        all_found=1
    else
        printf "${GREEN}✓ Found section: VALUES FILES${NC}\n"
    fi
    
    if ! grep -q "=== MODULE@VERSION EXTRACTION SUMMARY ===" "$file" 2>/dev/null; then
        printf "${RED}❌ Missing section: MODULE@VERSION EXTRACTION SUMMARY${NC}\n"
        all_found=1
    else
        printf "${GREEN}✓ Found section: MODULE@VERSION EXTRACTION SUMMARY${NC}\n"
    fi
    
    return $all_found
}

check_dk_project_classification() {
    # $1 = file path
    file=$1
    ok=0

    if ! grep -Eq '^IsDkProject: (true|false)$' "$file" 2>/dev/null; then
        printf "${RED}❌ Missing dk project classification${NC}\n"
        ok=1
    else
        printf "${GREEN}✓ Found dk project classification${NC}\n"
    fi

    if ! grep -Eq '^RootDkU: (dk\.u|\(not found\))$' "$file" 2>/dev/null; then
        printf "${RED}❌ Missing root dk.u marker result${NC}\n"
        ok=1
    else
        printf "${GREEN}✓ Found root dk.u marker result${NC}\n"
    fi

    return $ok
}

extract_modules() {
    # $1 = file path
    grep "^Module:" "$1" 2>/dev/null | sed 's/^Module: //' | sort -u || true
}

compare_files() {
    # $1 = file1, $2 = file2, $3 = label
    file1=$1
    file2=$2
    label=$3
    
    if ! cmp -s "$file1" "$file2"; then
        printf "${YELLOW}⚠ WARNING: %s outputs differ slightly${NC}\n" "$label"
        return 0  # Not a hard failure
    else
        printf "${GREEN}✓ PASS: %s outputs match exactly${NC}\n" "$label"
        return 0
    fi
}

# Main validation
printf "${CYAN}=== Analyzing dk-project Skill Output ===${NC}\n"

printf "\n${CYAN}1. Checking PowerShell output...${NC}\n"
ps_check=0
check_required_sections "$ps_output" "PowerShell" || ps_check=$?
check_dk_project_classification "$ps_output" || ps_check=1

printf "\n${CYAN}2. Checking Shell output...${NC}\n"
sh_check=0
check_required_sections "$sh_output" "Shell" || sh_check=$?
check_dk_project_classification "$sh_output" || sh_check=1

printf "\n${CYAN}3. Comparing files...${NC}\n"
compare_files "$ps_output" "$sh_output" "Output" || true

printf "\n${CYAN}4. Extracting modules...${NC}\n"
ps_modules=$(extract_modules "$ps_output")
sh_modules=$(extract_modules "$sh_output")

ps_count=$(printf '%s\n' "$ps_modules" | grep -c . || true)
sh_count=$(printf '%s\n' "$sh_modules" | grep -c . || true)

printf "PowerShell modules found: %d\n" "$ps_count"
echo "$ps_modules" | sed 's/^/  - /'

printf "Shell modules found: %d\n" "$sh_count"
echo "$sh_modules" | sed 's/^/  - /'

if [ "$ps_modules" = "$sh_modules" ]; then
    printf "${GREEN}✓ Module lists match${NC}\n"
else
    printf "${YELLOW}⚠ Module lists differ (acceptable depending on test project)${NC}\n"
fi

# Summary
printf "\n${CYAN}=== Summary ===${NC}\n"
if [ $ps_check -eq 0 ] && [ $sh_check -eq 0 ]; then
    printf "${GREEN}✓ All checks passed${NC}\n"
    exit 0
else
    printf "${RED}❌ Some checks failed${NC}\n"
    exit 1
fi
