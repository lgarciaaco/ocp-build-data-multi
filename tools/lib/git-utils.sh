#!/usr/bin/env bash
# Git utilities for OpenShift Build Data multi-version tools

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Initialize git worktree for a specific version
init_worktree() {
    local version="$1"
    local force="${2:-false}"
    local version_dir
    version_dir="$(get_version_dir "$version")"
    local branch_name
    branch_name="$(get_branch_name "$version")"
    
    log_info "Initializing worktree for version $version"
    
    # Check if worktree already exists
    if [[ -d "$version_dir" ]] && [[ "$force" != "true" ]]; then
        log_warning "Worktree for version $version already exists at $version_dir"
        return 0
    fi
    
    # Remove existing worktree if force is enabled
    if [[ -d "$version_dir" ]] && [[ "$force" == "true" ]]; then
        log_info "Removing existing worktree for version $version"
        git worktree remove "$version_dir" --force 2>/dev/null || true
        rm -rf "$version_dir" 2>/dev/null || true
    fi
    
    # Create the worktree
    if git worktree add "$version_dir" "$UPSTREAM_REMOTE/$branch_name" 2>/dev/null; then
        log_success "Created worktree for version $version at $version_dir"
        
        # Configure remotes in the worktree
        (
            cd "$version_dir" || return || return
            configure_remotes
        )
        
        return 0
    else
        log_error "Failed to create worktree for version $version"
        return 1
    fi
}

# Configure git remotes in a worktree
configure_remotes() {
    local current_dir
    current_dir="$(pwd)"
    
    # Add personal remote if it doesn't exist
    if ! git remote | grep -q "^${PERSONAL_REMOTE}$"; then
        log_debug "Adding remote $PERSONAL_REMOTE"
        git remote add "$PERSONAL_REMOTE" "$PERSONAL_URL"
    fi
    
    # Set up push remote
    git config "remote.${PERSONAL_REMOTE}.pushurl" "$PERSONAL_URL"
    
    # Fetch all remotes
    log_debug "Fetching remotes in $(basename "$current_dir")"
    git fetch --all --quiet
}

# Remove worktree for a specific version
remove_worktree() {
    local version="$1"
    local version_dir
    version_dir="$(get_version_dir "$version")"
    
    if [[ ! -d "$version_dir" ]]; then
        log_warning "Worktree for version $version does not exist"
        return 0
    fi
    
    log_info "Removing worktree for version $version"
    
    if git worktree remove "$version_dir" --force; then
        log_success "Removed worktree for version $version"
        return 0
    else
        log_error "Failed to remove worktree for version $version"
        return 1
    fi
}

# Update all worktrees
update_worktrees() {
    local versions=("$@")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    log_info "Updating worktrees for versions: ${versions[*]}"
    
    # First, update the main repository
    log_info "Fetching latest changes from upstream"
    git fetch --all
    
    # Update each worktree
    for version in "${versions[@]}"; do
        local version_dir
    version_dir="$(get_version_dir "$version")"
        
        if [[ ! -d "$version_dir" ]]; then
            log_warning "Worktree for version $version does not exist, skipping"
            continue
        fi
        
        log_info "Updating worktree for version $version"
        (
            cd "$version_dir" || return || return
            local branch_name
            branch_name="$(get_branch_name "$version")"
            
            # Pull latest changes
            if git pull "$UPSTREAM_REMOTE" "$branch_name" --ff-only; then
                log_success "Updated worktree for version $version"
            else
                log_warning "Failed to update worktree for version $version (may have local changes)"
            fi
        )
    done
}

# Check worktree status
check_worktree_status() {
    local version="$1"
    local version_dir
    version_dir="$(get_version_dir "$version")"
    
    if [[ ! -d "$version_dir" ]]; then
        echo "missing"
        return 1
    fi
    
    (
        cd "$version_dir" || return
        
        # Check if there are uncommitted changes
        if ! git diff-index --quiet HEAD --; then
            echo "dirty"
            return 1
        fi
        
        # Check if there are untracked files
        if [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
            echo "untracked"
            return 1
        fi
        
        # Check if branch is ahead/behind
        local branch_name
        branch_name="$(get_branch_name "$version")"
        local local_ref
        local_ref="$(git rev-parse HEAD)"
        local remote_ref
        remote_ref="$(git rev-parse "$UPSTREAM_REMOTE/$branch_name" 2>/dev/null || echo "")"
        
        if [[ -z "$remote_ref" ]]; then
            echo "no-remote"
            return 1
        elif [[ "$local_ref" != "$remote_ref" ]]; then
            echo "diverged"
            return 1
        fi
        
        echo "clean"
        return 0
    )
}

# Create and push a new branch
create_branch() {
    local version="$1"
    local branch_name="$2"
    local base_branch="${3:-$(get_branch_name "$version")}"
    local version_dir
    version_dir="$(get_version_dir "$version")"
    
    if [[ ! -d "$version_dir" ]]; then
        log_error "Worktree for version $version does not exist"
        return 1
    fi
    
    log_info "Creating branch $branch_name for version $version"
    
    (
        cd "$version_dir" || return
        
        # Create the branch
        if git checkout -b "$branch_name" "$base_branch"; then
            log_success "Created branch $branch_name for version $version"
            
            # Push to personal remote
            if git push -u "$PERSONAL_REMOTE" "$branch_name"; then
                log_success "Pushed branch $branch_name to $PERSONAL_REMOTE"
                return 0
            else
                log_error "Failed to push branch $branch_name"
                return 1
            fi
        else
            log_error "Failed to create branch $branch_name for version $version"
            return 1
        fi
    )
}

# Commit changes in a worktree
commit_changes() {
    local version="$1"
    local message="$2"
    local version_dir
    version_dir="$(get_version_dir "$version")"
    
    if [[ ! -d "$version_dir" ]]; then
        log_error "Worktree for version $version does not exist"
        return 1
    fi
    
    log_info "Committing changes in version $version"
    
    (
        cd "$version_dir" || return
        
        # Check if there are changes to commit
        if git diff-index --quiet HEAD --; then
            log_warning "No changes to commit in version $version"
            return 0
        fi
        
        # Add all changes
        git add -A
        
        # Commit with the provided message
        if git commit -m "$message"; then
            log_success "Committed changes in version $version"
            return 0
        else
            log_error "Failed to commit changes in version $version"
            return 1
        fi
    )
}

# Push changes to personal remote
push_changes() {
    local version="$1"
    local branch_name="${2:-$(git -C "$(get_version_dir "$version")" branch --show-current)}"
    local version_dir
    version_dir="$(get_version_dir "$version")"
    
    if [[ ! -d "$version_dir" ]]; then
        log_error "Worktree for version $version does not exist"
        return 1
    fi
    
    log_info "Pushing changes for version $version"
    
    (
        cd "$version_dir" || return
        
        if git push "$PERSONAL_REMOTE" "$branch_name"; then
            log_success "Pushed changes for version $version to $PERSONAL_REMOTE/$branch_name"
            return 0
        else
            log_error "Failed to push changes for version $version"
            return 1
        fi
    )
}

# Show git status for worktrees
show_worktree_status() {
    local versions=("$@")
    
    if [[ ${#versions[@]} -eq 0 ]]; then
        read -ra versions <<< "$ACTIVE_VERSIONS"
    fi
    
    printf "%-8s %-12s %-15s %s\n" "VERSION" "STATUS" "BRANCH" "CHANGES"
    printf "%-8s %-12s %-15s %s\n" "-------" "------" "------" "-------"
    
    for version in "${versions[@]}"; do
        local version_dir
    version_dir="$(get_version_dir "$version")"
        local status
        status="$(check_worktree_status "$version")"
        local branch=""
        local changes=""
        
        if [[ -d "$version_dir" ]]; then
            branch="$(git -C "$version_dir" branch --show-current 2>/dev/null || echo "unknown")"
            
            # Count changes
            local modified
            modified="$(git -C "$version_dir" diff --name-only | wc -l | xargs)"
            local staged
            staged="$(git -C "$version_dir" diff --cached --name-only | wc -l | xargs)"
            local untracked
            untracked="$(git -C "$version_dir" ls-files --others --exclude-standard | wc -l | xargs)"
            
            changes="M:$modified S:$staged U:$untracked"
        else
            branch="N/A"
            changes="N/A"
        fi
        
        printf "%-8s %-12s %-15s %s\n" "$version" "$status" "$branch" "$changes"
    done
}