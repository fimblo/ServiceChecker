  ![Build Status](https://github.com/fimblo/ServiceChecker/actions/workflows/build.yml/badge.svg)

# ServiceChecker

ServiceChecker is a macOS status bar application that monitors the health
of web services. The services' statuses are visible in your menu bar, making
it easy to keep track of your services' availability.

<p align="center">
  <img
    alt="ServiceChecker"
    width="246"
    height="207"
    src="/.docs/ServiceChecker.png"
  >
</p>


## Features

- 🔍 Monitors multiple web services simultaneously
- 🔌 Toggle monitoring of services individually, or all at once
- 🕒 Easy configuration by modifying json file
- 🚦 Visual status indicators in the menu bar

> **Warning**
> This app is designed for monitoring your own services. Frequent polling of
> external services should only be done with explicit permission from the
> service owner.

## Installation

1. Download the latest version from [Releases](https://github.com/fimblo/ServiceChecker/releases)
2. Unzip, then Right-click (or Control-click) on ServiceChecker.app
4. Select "Open" from the context menu
5. Click "Open" in the security dialog that appears
6. The app will now start and appear in your status bar

Note: After the first launch using these steps, you can open the app normally
by double-clicking.

## Configuration

### Services Configuration

Finding the configuration file:
1. Open the app
2. Click on the status bar icon
3. Click on "Open Config Directory"
4. Read the instructions in the README.md file, then modify `config.json`


## Known Issues

See the GitHub issues page: https://github.com/fimblo/ServiceChecker/issues
