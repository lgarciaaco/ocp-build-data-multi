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

# Set value in YAML file using yq
yaml_set() {
    local file="$1"
    local path="$2"
    local value="$3"
    local backup="${4:-true}"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Create backup if requested
    if [[ "$backup" == "true" ]]; then
        cp "$file" "${file}.bak"
    fi
    
    # Apply the change
    if yq eval "${path} = \"${value}\"" -i "$file"; then
        log_debug "Updated $path in $file to: $value"
        return 0
    else
        log_error "Failed to update $path in $file"
        # Restore backup if operation failed
        if [[ "$backup" == "true" && -f "${file}.bak" ]]; then
            mv "${file}.bak" "$file"
        fi
        return 1
    fi
}

# Delete a key from YAML file
yaml_delete() {
    local file="$1"
    local path="$2"
    local backup="${3:-true}"
    
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi
    
    # Create backup if requested
    if [[ "$backup" == "true" ]]; then
        cp "$file" "${file}.bak"
    fi
    
    # Delete the key
    if yq eval "del($path)" -i "$file"; then
        log_debug "Deleted $path from $file"
        return 0
    else
        log_error "Failed to delete $path from $file"
        # Restore backup if operation failed
        if [[ "$backup" == "true" && -f "${file}.bak" ]]; then
            mv "${file}.bak" "$file"
        fi
        return 1
    fi
}

# Check if a path exists in YAML file
yaml_has() {
    local file="$1"
    local path="$2"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    local value="$(yaml_get "$file" "$path")"
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
        local version_dir="$(get_version_dir "$version")"
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
        local version_dir="$(get_version_dir "$version")"
        
        if [[ ! -d "$version_dir" ]]; then
            continue
        fi
        
        log_info "Checking version $version..."
        
        find "$version_dir" -name "$file_pattern" -type f | while read -r file; do
            local value="$(yaml_get "$file" "$yaml_path")"
            
            if [[ "$value" == "$expected_value" ]]; then
                local relative_path="${file#$version_dir/}"
                echo "$version:$relative_path"
            fi
        done
    done
}

# Apply YAML transformation across versions
yaml_transform() {
    local file_pattern="$1"
    local yaml_path="$2"
    local operation="$3"  # set, delete, or script
    local value="$4"      # value for set operation or script content
    local versions=("${@:5}")
    local dry_run="${DRY_RUN:-false}"
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    log_info "Applying YAML transformation to $file_pattern"
    log_info "Operation: $operation on path $yaml_path"
    
    for version in "${versions[@]}"; do
        local version_dir="$(get_version_dir "$version")"
        
        if [[ ! -d "$version_dir" ]]; then
            log_warning "Worktree for version $version does not exist, skipping"
            continue
        fi
        
        log_info "Processing version $version..."
        
        find "$version_dir" -name "$file_pattern" -type f | while read -r file; do
            local relative_path="${file#$version_dir/}"
            
            # Check if the path exists in the file
            if [[ "$operation" != "set" ]] && ! yaml_has "$file" "$yaml_path"; then
                log_debug "Path $yaml_path not found in $relative_path, skipping"
                continue
            fi
            
            log_info "  $relative_path"
            
            if [[ "$dry_run" == "true" ]]; then
                local current_value="$(yaml_get "$file" "$yaml_path")"
                echo "    Would $operation $yaml_path (current: $current_value)"
                continue
            fi
            
            case "$operation" in
                "set")
                    yaml_set "$file" "$yaml_path" "$value"
                    ;;
                "delete")
                    yaml_delete "$file" "$yaml_path"
                    ;;
                "script")
                    # Execute custom yq script
                    if yq eval "$value" -i "$file"; then
                        log_debug "Applied custom script to $relative_path"
                    else
                        log_error "Failed to apply script to $relative_path"
                    fi
                    ;;
                *)
                    log_error "Unknown operation: $operation"
                    return 1
                    ;;
            esac
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
        local version_dir="$(get_version_dir "$version")"
        
        if [[ ! -d "$version_dir" ]]; then
            continue
        fi
        
        find "$version_dir/images" -name "*.yml" -type f | while read -r file; do
            local network_mode="$(yaml_get "$file" ".konflux.network_mode")"
            local has_lockfile="$(yaml_has "$file" ".konflux.cachi2.lockfile")"
            local relative_path="${file#$version_dir/}"
            
            # If no explicit network_mode, it defaults to hermetic from group.yml
            if [[ "$network_mode" == "null" || "$network_mode" == "hermetic" ]]; then
                if ! $has_lockfile; then
                    echo "$version:$relative_path:missing-lockfile"
                fi
            fi
        done
    done
}