# ServiceChecker

ServiceChecker is a macOS status bar application that monitors the health of web services.
The services' statuses are visible in your menu bar, making it easy to keep track of your
services' availability.

## Features

- 🔍 Monitors multiple web services simultaneously
- 🕒 Configurable update intervals (1-60 seconds)
- 🚦 Visual status indicators in the menu bar

## Installation

Since this is an unsigned application, you'll need to follow these steps when first launching it:

1. Drag ServiceChecker.app to your Applications folder
2. Right-click (or Control-click) on ServiceChecker.app
3. Select "Open" from the context menu
4. Click "Open" in the security dialog that appears
5. The app will now start and appear in your status bar

Note: After the first launch using these steps, you can open the app normally by double-clicking.

## Configuration

### Services Configuration

The list of services is configured by modifying the `services.json` file.

The app runs in a sandbox, and the root of the sandox is `~/Library/Containers/org.yanson.ServiceChecker/Data`. 
`services.json` is located at: 

```
$SANDBOX_ROOT/Library/Application Support/ServiceChecker/services.json
```

## Known Issues

- Pressing Preferences... does not work. It will raise the app to the foreground, and you will need to go to ServiceChecker->Settings manually.
- The "do not show again" checkbox does not work well. It works the first time, but if you mark that you want to see the window again, it will not show. You have to either run `defaults delete org.yanson.ServiceChecker` or open it manually.
- Since the app is unsigned and not notarized:
  - macOS will show a security warning on first launch
  - Users will need to use the right-click > Open method for first launch
  - Some organizations might block unsigned apps by policy

