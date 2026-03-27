# Open a cmux workspace with terminal | browser + lazygit layout
cmux-workspace() {
  local dir="${1:?Usage: cmux-workspace <directory>}"
  dir="${dir%/}"
  dir="$(cd "$dir" 2>/dev/null && pwd)" || { echo "Directory not found: $1"; return 1; }

  # Title Case from basename: "my-project" -> "My Project"
  local name="$(basename "$dir" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2))}1')"

  # Check for existing workspace with the same name
  local existing_ws="$(cmux list-workspaces | grep -F "$name" | awk '{print $1}')"
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

  # Create workspace with terminal in project dir
  local ws_output="$(cmux new-workspace --cwd "$dir")"
  local ws_id="$(echo "$ws_output" | awk '{print $2}')"

  # Rename workspace to title-cased name
  cmux rename-workspace --workspace "$ws_id" "$name"

  # Split right for browser pane
  local browser_output="$(cmux new-pane --type browser --direction right --workspace "$ws_id")"
  local browser_surface="$(echo "$browser_output" | awk '{print $2}')"

  # Split browser pane down for lazygit terminal (target browser surface)
  local lg_output="$(cmux new-split down --workspace "$ws_id" --surface "$browser_surface")"
  local lg_surface="$(echo "$lg_output" | awk '{print $2}')"

  # Launch lazygit in the bottom-right pane
  cmux send --workspace "$ws_id" --surface "$lg_surface" "cd $dir && lazygit\n"
}
