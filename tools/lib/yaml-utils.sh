#!/usr/bin/env bash
# YAML utilities for OpenShift Build Data multi-version tools

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Extract value from YAML file using yq
yaml_get() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    yq eval "$path" "$file" 2>/dev/null || echo "null"
}



# Check if a path exists in YAML file
yaml_has() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local value
    value="$(yaml_get "$file" "$path")"
    [[ "$value" != "null" ]]
}

# Get all keys at a specific path
yaml_keys() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    yq eval "${path} | keys | .[]" "$file" 2>/dev/null
}

# Compare YAML values across versions
yaml_compare() {
    local file_path="$1"
    local yaml_path="$2"
    local versions=("${@:3}")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    log_info "Comparing $yaml_path in $file_path across versions"
    
    printf "%-8s %s\n" "VERSION" "VALUE"
    printf "%-8s %s\n" "-------" "-----"
    
    for version in "${versions[@]}"; do
        local version_dir
        version_dir="$(get_version_dir "$version")"
        local full_path="$version_dir/$file_path"
        local value="N/A"
        
        if [[ -f "$full_path" ]]; then
            value="$(yaml_get "$full_path" "$yaml_path")"
            if [[ "$value" == "null" ]]; then
                value="(not set)"
            fi
        fi
        
        printf "%-8s %s\n" "$version" "$value"
    done
}

# Find files with specific YAML patterns
yaml_find() {
    local yaml_path="$1"
    local expected_value="$2"
    local file_pattern="${3:-*.yml}"
    local versions=("${@:4}")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    log_info "Finding files with $yaml_path = '$expected_value' in pattern '$file_pattern'"
    
    for version in "${versions[@]}"; do
        local version_dir
        version_dir="$(get_version_dir "$version")"
        
        if [[ ! -d "$version_dir" ]]; then
            continue
        fi
        
        log_info "Checking version $version..."
        
        find "$version_dir" -path "*/$file_pattern" -type f | while read -r file; do
            local value
            value="$(yaml_get "$file" "$yaml_path")"
            
            if [[ "$value" == "$expected_value" ]]; then
                local relative_path="${file#"$version_dir"/}"
                echo "$version:$relative_path"
            fi
        done
    done
}


# Validate YAML syntax
yaml_validate() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    if yq eval '.' "$file" > /dev/null 2>&1; then
        return 0
    else
        log_error "Invalid YAML syntax in $file"
        return 1
    fi
}

# Extract hermetic conversion candidates
find_hermetic_candidates() {
    local versions=("$@")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    log_info "Finding images with network_mode: open (hermetic conversion candidates)"
    
    yaml_find ".konflux.network_mode" "open" "images/*.yml" "${versions[@]}"
}

# Check for missing lockfiles in hermetic builds
check_hermetic_lockfiles() {
    local versions=("$@")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    log_info "Checking for missing cachi2 lockfiles in potential hermetic builds"
    
    for version in "${versions[@]}"; do
        local version_dir
        version_dir="$(get_version_dir "$version")"
        
        if [[ ! -d "$version_dir" ]]; then
            continue
        fi
        
        find "$version_dir/images" -name "*.yml" -type f | while read -r file; do
            local network_mode
            network_mode="$(yaml_get "$file" ".konflux.network_mode")"
            local has_lockfile
            has_lockfile="$(yaml_has "$file" ".konflux.cachi2.lockfile")"
            local relative_path="${file#"$version_dir"/}"
            
            # If no explicit network_mode, it defaults to hermetic from group.yml
            if [[ "$network_mode" == "null" || "$network_mode" == "hermetic" ]]; then
                if ! $has_lockfile; then
                    echo "$version:$relative_path:missing-lockfile"
                fi
            fi
        done
    done
}