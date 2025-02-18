# ServiceChecker

## Overview
This is the configuration directory for ServiceChecker; a macOS
app for monitoring your own services.

```
$ tree
.
├── README.txt     # overwritten at startup. Yes, this file.
└── config.json    # overwritten on config change.
```

## Configuration

`config.json` contains the list of services to monitor and other
configuration options. Each service should have a name and a health 
check URL. ServiceChecker assumes that a returning 200 status code
means the service is up.

The minimal format is:

```json
{
    "services": [
        {
            "name": "Service Name",
            "url": "http://localhost",
        }
    ]
}
```

The full format, with all optional fields:

```json
{
    "services": [
        {
            "name": "Service Name",
            "url": "http://localhost:8080/path/to/health/check",
            "mode": "enabled",
        },
        {
            "name": "Service Name 2",
            "url": "http://localhost:8080/path/to/health/check",
            "mode": "disabled",
        }
    ],
    "symbolUp": "🟢",             /* or any other unicode character */
    "symbolDown": "🔴",           /* or any other unicode character */
    "symbolDisabled": "⚪",       /* or any other unicode character */
    "updateIntervalSeconds": 10   /* 1-60 seconds */
}
```

You can have multiple services, one after another. I haven't tested
how many services you can have, but it's probably fun to find out if
you're into that kind of thing. 