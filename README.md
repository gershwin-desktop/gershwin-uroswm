## Gershwin Window Manager

### Overview of source components

* WindowManagerDelegate -> This registers the Window Manager and acts as an event loop handler.

* XCBWrapper -> These are the methods which talk to XCB lirbaries and do X related things, only the delegate should call these methods.

* ThemeRenderer -> This handles drawing with GSTheme, only XCBWrapper should call these methods.
