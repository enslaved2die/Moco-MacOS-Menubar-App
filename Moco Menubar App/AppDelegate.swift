import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        
        NSApp.setActivationPolicy(.prohibited)
        // Create the menubar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "MocoIconTray")
            button.action = #selector(togglePopover)
            
        }

        // Create the popover with the BookingView
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 350)
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: BookingView())
        popover.behavior = .transient
    }

    @objc func togglePopover() {
        // Toggle the popover visibility
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
}
