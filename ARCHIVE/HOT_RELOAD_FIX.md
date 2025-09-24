# Hot Reload Fix Guide

## How to Run Flutter with Hot Reload

### For Terminal Users
**You must run this yourself in your terminal:**

1. Open Terminal app on your Mac
2. Navigate to project:
   ```bash
   cd "/Users/kahnja/Projects/Modia/Audio Learning App"
   ```
3. Run the development script:
   ```bash
   ./flutter_dev.sh
   ```
4. Once app is running, press 'r' for hot reload

### For VS Code Users
1. Open the project in VS Code
2. Press `F5` to start debugging
3. Hot reload happens automatically when you save files (`Cmd+S`)

## Important Note
**The flutter_dev.sh script must be run by YOU directly in Terminal, not through Claude.** This is because hot reload requires keyboard input, which only works when you run it yourself.

## Hot Reload Keys
- `r` = Hot reload 🔥
- `R` = Hot restart
- `q` = Quit app