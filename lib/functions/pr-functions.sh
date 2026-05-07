#!/usr/bin/env bash
#
# pr-functions.sh
#
# Implementation of `hanif pr`. See lib/commands/pr.sh for the dispatcher
# and help screens.

# Strict regex: a remote name must match git's own naming rules well enough
# for our purposes. Reject anything weird before passing it to git.
_HANIF_PR_REMOTE_RE='^[A-Za-z0-9._/-]+$'
# Branch names: a permissive but safe subset (no spaces, no shell metas).
_HANIF_PR_BRANCH_RE='^[A-Za-z0-9._/+-]+$'

# ---------------------------------------------------------------------------
# Remote URL parsing
# ---------------------------------------------------------------------------

# Normalise a git remote URL into "host\towner\trepo" (TAB-separated).
# Handles SSH (`git@github.com:owner/repo.git`),
# HTTPS (`https://github.com/owner/repo.git`),
# git protocol, and Azure DevOps' two URL flavours.
# Echoes nothing and returns 1 if the URL cannot be parsed.
_hanif_pr_parse_remote() {
  local url="$1"
  local host="" owner="" repo=""

  # Strip trailing .git for cleaner downstream URLs.
  url="${url%.git}"
  url="${url%/}"

  if [[ "$url" =~ ^git@([^:]+):(.+)$ ]]; then
    # SSH form: git@host:path
    host="${BASH_REMATCH[1]}"
    local path="${BASH_REMATCH[2]}"
    _hanif_pr_split_path "$host" "$path"
    return $?
  elif [[ "$url" =~ ^ssh://(git@)?([^/]+)/(.+)$ ]]; then
    host="${BASH_REMATCH[2]}"
    local path="${BASH_REMATCH[3]}"
    # Azure DevOps SSH uses ssh://git@ssh.dev.azure.com/v3/<org>/<project>/<repo>
    if [[ "$host" == ssh.dev.azure.com ]]; then
      # Map back to dev.azure.com web host.
      host="dev.azure.com"
      # Strip leading "v3/".
      path="${path#v3/}"
    fi
    _hanif_pr_split_path "$host" "$path"
    return $?
  elif [[ "$url" =~ ^https?://([^@/]+@)?([^/]+)/(.+)$ ]]; then
    host="${BASH_REMATCH[2]}"
    local path="${BASH_REMATCH[3]}"
    # Azure DevOps HTTPS: https://dev.azure.com/<org>/<project>/_git/<repo>
    # Or: https://<org>.visualstudio.com/<project>/_git/<repo>
    if [[ "$host" == *visualstudio.com ]]; then
      # <org>.visualstudio.com — extract org from host.
      local org="${host%%.visualstudio.com}"
      host="dev.azure.com"
      # Path looks like: <project>/_git/<repo>  -> rewrite as org/project/repo
      if [[ "$path" =~ ^([^/]+)/_git/([^/]+)$ ]]; then
        printf '%s\t%s\t%s\t%s\n' "$host" "$org" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        return 0
      fi
      return 1
    fi
    if [[ "$host" == dev.azure.com ]]; then
      if [[ "$path" =~ ^([^/]+)/([^/]+)/_git/([^/]+)$ ]]; then
        printf '%s\t%s\t%s\t%s\n' "$host" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
        return 0
      fi
      return 1
    fi
    _hanif_pr_split_path "$host" "$path"
    return $?
  fi
  return 1
}

# Split a "owner/repo" path for hosts that follow that flat layout.
# GitLab subgroups produce "group/subgroup/repo" — we keep everything
# before the last segment as "owner".
_hanif_pr_split_path() {
  local host="$1"
  local path="$2"
  local owner="${path%/*}"
  local repo="${path##*/}"
  if [[ -z "$owner" || -z "$repo" || "$owner" == "$path" ]]; then
    return 1
  fi
  printf '%s\t%s\t%s\n' "$host" "$owner" "$repo"
}

# ---------------------------------------------------------------------------
# URL builders
# ---------------------------------------------------------------------------

# Build a compare/PR-create URL. Args: host owner [project] repo base head.
# For Azure DevOps the third positional is the project (4 path parts);
# for everything else only owner/repo are used (3 parts).
_hanif_pr_build_url() {
  local host="$1"; shift
  local base head url
  case "$host" in
    github.com|*.github.com|github.*)
      local owner="$1" repo="$2"; base="$3"; head="$4"
      url="https://${host}/${owner}/${repo}/compare/${base}...${head}?expand=1"
      ;;
    gitlab.com|*.gitlab.com|gitlab.*)
      local owner="$1" repo="$2"; base="$3"; head="$4"
      url="https://${host}/${owner}/${repo}/-/compare/${base}...${head}"
      ;;
    dev.azure.com)
      local org="$1" project="$2" repo="$3"; base="$4"; head="$5"
      url="https://${host}/${org}/${project}/_git/${repo}/pullrequestcreate?sourceRef=${head}&targetRef=${base}"
      ;;
    bitbucket.org)
      local owner="$1" repo="$2"; base="$3"; head="$4"
      url="https://${host}/${owner}/${repo}/pull-requests/new?source=${head}&dest=${base}"
      ;;
    *)
      return 1
      ;;
  esac
  echo "$url"
}

# ---------------------------------------------------------------------------
# Top-level
# ---------------------------------------------------------------------------

hanif_pr() {
  local action="open"
  local remote="origin"
  local base=""
  local positional=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --remote)
        remote="${2:-}"
        shift 2 || { error "--remote requires a value"; return 1; }
        ;;
      --base)
        base="${2:-}"
        shift 2 || { error "--base requires a value"; return 1; }
        ;;
      url|copy|open)
        positional+=("$1"); shift
        ;;
      *)
        error "Unknown argument: $1"
        return 1
        ;;
    esac
  done

  if [[ ${#positional[@]} -gt 0 ]]; then
    action="${positional[0]}"
  fi

  is_git_repo || { error "Not inside a git repository"; return 1; }

  if [[ ! "$remote" =~ $_HANIF_PR_REMOTE_RE ]]; then
    error "Invalid remote name: $remote"
    return 1
  fi

  local remote_url
  if ! remote_url=$(git remote get-url "$remote" 2>/dev/null); then
    error "Remote not found: $remote"
    hint "Use --remote to pick a different one. Configured remotes:"
    git remote -v 2>/dev/null | sed 's/^/  /' >&2
    return 1
  fi

  local parsed
  if ! parsed=$(_hanif_pr_parse_remote "$remote_url"); then
    error "Could not parse remote URL: $remote_url"
    hint "Supported hosts: github.com, gitlab.com, dev.azure.com, bitbucket.org"
    return 1
  fi

  local head
  head=$(get_current_branch)
  if [[ -z "$head" || "$head" == "HEAD" ]]; then
    error "Detached HEAD — switch to a branch first"
    return 1
  fi
  if [[ ! "$head" =~ $_HANIF_PR_BRANCH_RE ]]; then
    error "Current branch name contains unsupported characters: $head"
    return 1
  fi

  if [[ -z "$base" ]]; then
    if git show-ref --verify --quiet refs/heads/main; then
      base="main"
    elif git show-ref --verify --quiet refs/heads/master; then
      base="master"
    else
      base="main"
    fi
  fi
  if [[ ! "$base" =~ $_HANIF_PR_BRANCH_RE ]]; then
    error "Invalid base branch name: $base"
    return 1
  fi
  if [[ "$base" == "$head" ]]; then
    warning "Current branch ($head) is the same as base ($base) — there is no PR to open"
    hint "Switch to a feature branch first, or use --base to compare against another branch"
    return 1
  fi

  # Split parsed (TAB-separated). For Azure DevOps it has 4 fields.
  local -a parts=()
  IFS=$'\t' read -r -a parts <<< "$parsed"
  local host="${parts[0]}"

  local url
  if [[ "$host" == "dev.azure.com" ]]; then
    url=$(_hanif_pr_build_url "$host" "${parts[1]}" "${parts[2]}" "${parts[3]}" "$base" "$head") || {
      error "Could not build PR URL for $host"; return 1; }
  else
    url=$(_hanif_pr_build_url "$host" "${parts[1]}" "${parts[2]}" "$base" "$head") || {
      error "Unsupported remote host: $host"; return 1; }
  fi

  case "$action" in
    url)
      echo "$url"
      ;;
    copy)
      if printf '%s' "$url" | hanif_clip_copy; then
        success "Copied PR URL to clipboard"
        hint "  $url"
      else
        warning "No clipboard tool available — printing URL instead"
        echo "$url"
      fi
      ;;
    open)
      info "Opening: $url"
      if ! hanif_open_url "$url"; then
        warning "Could not open browser — URL printed above"
        return 1
      fi
      ;;
    *)
      error "Unknown action: $action"
      return 1
      ;;
  esac
}
