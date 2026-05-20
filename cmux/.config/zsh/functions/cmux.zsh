# Open a cmux workspace with a two-column layout: claude on the left, plain terminal on the right
cmux-workspace() {
  local dir="${1:?Usage: cmux-workspace <directory>}"
  dir="${dir%/}"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || { echo "Directory not found: $1"; return 1; }

  # Title Case from basename: "my-project" -> "My Project"
  local name="$(basename "$dir" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"

  # Check for existing workspace with the same name
  local existing_ws="$(cmux list-workspaces | grep -F "$name" | awk '{for(i=1;i<=NF;i++) if($i ~ /^workspace:/) {print $i; exit}}')"
  if [[ -n "$existing_ws" ]]; then
    echo "Workspace \"$name\" already exists ($existing_ws)."
    read -r "choice?Switch to it? [Y/n/c(lose & recreate)] "
    case "${choice:-y}" in
      [nN]) return 0 ;;
      [cC])
        cmux close-workspace --workspace "$existing_ws"
        ;;
      *)
        cmux select-workspace --workspace "$existing_ws"
        return 0
        ;;
    esac
  fi

  # Create the workspace with claude running in the initial (left) pane,
  # then split a plain terminal on the right. Workspace-level --command works
  # reliably; the per-surface `command` inside --layout JSON is silently
  # dropped in cmux 0.64.6.
  local ws_output="$(cmux new-workspace --cwd "$dir" --command "claude")"
  local ws_id="$(echo "$ws_output" | awk '{print $2}')"

  cmux rename-workspace --workspace "$ws_id" "$name"

  cmux new-pane --type terminal --direction right --workspace "$ws_id" >/dev/null
}
