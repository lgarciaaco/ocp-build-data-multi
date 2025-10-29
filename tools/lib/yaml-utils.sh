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

# Format YAML value for display
format_yaml_value() {
    local value="$1"
    local preserve_structure="${2:-false}"
    
    if [[ "$value" == "null" ]]; then
        echo "(not set)"
        return
    fi
    
    if [[ "$value" == "N/A" ]]; then
        echo "$value"
        return
    fi
    
    # For complex YAML structures, preserve them
    if [[ "$preserve_structure" == "true" ]]; then
        echo "$value"
    else
        # Simple formatting for compact display
        if [[ "$value" == *$'\n'* ]]; then
            # For compact formats, use abbreviated form
            local line_count
            line_count=$(echo "$value" | wc -l)
            local first_line
            first_line=$(echo "$value" | head -n1)
            echo "${first_line}... (${line_count} lines)"
        else
            echo "$value"
        fi
    fi
}

# Compare YAML values across versions
yaml_compare() {
    local file_path="$1"
    local yaml_path="$2"
    local versions=("${@:3}")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    echo "=== YAML Path Comparison ==="
    echo "File: $file_path"
    echo "Path: $yaml_path"
    echo
    
    for version in "${versions[@]}"; do
        local version_dir
        version_dir="$(get_version_dir "$version")"
        local full_path="$version_dir/$file_path"
        
        echo "--- Version $version ---"
        
        if [[ -f "$full_path" ]]; then
            local value
            value="$(yaml_get "$full_path" "$yaml_path")"
            
            if [[ "$value" == "null" ]]; then
                echo "(not set)"
            else
                # Display the actual YAML content with proper formatting
                echo "$value"
            fi
        else
            echo "(file not found)"
        fi
        echo
    done
}

# Compare YAML values in side-by-side format
yaml_compare_side_by_side() {
    local file_path="$1"
    local yaml_path="$2"
    local versions=("${@:3}")
    
    if [[ ${#versions[@]} -ne 2 ]]; then
        log_error "Side-by-side comparison requires exactly 2 versions"
        return 1
    fi
    
    echo "=== YAML Path Side-by-Side Comparison ==="
    echo "File: $file_path"
    echo "Path: $yaml_path"
    echo
    
    local version1="${versions[0]}"
    local version2="${versions[1]}"
    
    local version_dir1
    version_dir1="$(get_version_dir "$version1")"
    local full_path1="$version_dir1/$file_path"
    
    local version_dir2
    version_dir2="$(get_version_dir "$version2")"
    local full_path2="$version_dir2/$file_path"
    
    local value1="N/A"
    local value2="N/A"
    
    if [[ -f "$full_path1" ]]; then
        value1="$(yaml_get "$full_path1" "$yaml_path")"
    fi
    
    if [[ -f "$full_path2" ]]; then
        value2="$(yaml_get "$full_path2" "$yaml_path")"
    fi
    
    # Format values for side-by-side display
    local formatted_value1
    formatted_value1="$(format_yaml_value "$value1" false)"
    local formatted_value2
    formatted_value2="$(format_yaml_value "$value2" false)"
    
    printf "%-12s | %-50s | %-50s\n" "COMPARISON" "$version1" "$version2"
    printf "%-12s | %-50s | %-50s\n" "$(printf '%*s' 12 '' | tr ' ' '-')" "$(printf '%*s' 50 '' | tr ' ' '-')" "$(printf '%*s' 50 '' | tr ' ' '-')"
    printf "%-12s | %-50s | %-50s\n" "Values" "$formatted_value1" "$formatted_value2"
    
    # Show difference indicator
    if [[ "$value1" == "$value2" ]]; then
        echo
        echo "✓ Values are identical"
    else
        echo
        echo "✗ Values differ"
    fi
}

# Compare YAML values in compact table format
yaml_compare_table() {
    local file_path="$1"
    local yaml_path="$2"
    local versions=("${@:3}")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    echo "YAML: $yaml_path | File: $file_path"
    
    printf "VERSION "
    for version in "${versions[@]}"; do
        printf "%-10s " "$version"
    done
    echo
    
    printf "%s " "-------"
    for version in "${versions[@]}"; do
        printf "%-10s " "----------"
    done
    echo
    
    printf "Value   "
    for version in "${versions[@]}"; do
        local version_dir
        version_dir="$(get_version_dir "$version")"
        local full_path="$version_dir/$file_path"
        local value="N/A"
        
        if [[ -f "$full_path" ]]; then
            value="$(yaml_get "$full_path" "$yaml_path")"
        fi
        
        local short_value
        short_value="$(format_yaml_value "$value" false)"
        printf "%-10s " "$short_value"
    done
    echo
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