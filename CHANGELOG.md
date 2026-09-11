## V0.1.1 A

- Initial setup of architecture and modules
    > Changed the way the menus work
    - added menu item descriptions
    - added new menus: settings, hotkeys, quit
    - changed how the UI flows, better layout 
- Settings menu
    > Added options to configure in the TUI
    - Added adjustable launch timing 
    - Added adjustable root folder
    - Added adjustable client option, Unity or Flash
- Setup Configs Folder
    > Cleaned up artifacts
    - Made the json format easier to read
    - Fixed issue that would cause the configs to be saved in random places
- Process Tracking & Bot Management
    > Monitor, inspect, and terminate active accounts
    - Captured OS process PID on bot launches
    - Added live uptime and PID status badges in TUI
    - Added 'K' hotkey to cleanly kill/terminate focused running bots
    - Persistent running sessions saved to configs/running_sessions.json
- Clickable Hyperlink
    > Interactive footer links
    - Added clickable (GitHub) repository link opening in default browser

## V0.1.0 A

- Initial setup of architecture and modules
- Initial Testing of Account and folder logic
- Setup Configs Folder