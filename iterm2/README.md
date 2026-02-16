# iTerm2 Preferences Sync

iTerm2 can load preferences from a custom directory.

## Setup

1. Open iTerm2
2. Go to **Settings > General > Preferences**
3. Check **Load preferences from a custom folder or URL**
4. Set path to: `~/dotfiles/iterm2/.config/iterm2/`
5. Optionally check **Save changes to folder when iTerm2 quits**

## Notes

- iTerm2 saves preferences as a `.plist` file
- Changes made in the GUI are written to the synced directory if "Save changes" is enabled
- After cloning dotfiles on a new machine, point iTerm2 to the custom folder and restart
