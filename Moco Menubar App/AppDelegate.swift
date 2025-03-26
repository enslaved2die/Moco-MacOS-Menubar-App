import Cocoa
import SwiftUI
import AppKit

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate, BookingDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover!
    var isIconVisible: Bool = true
    var timer: Timer?
    var lastBookingDate: Date?
    var blinkHold: Double = 0.5
    var isBlinking = false
    
    let openIcon = NSImage(named: "MocoIconTray")
    let closedIcon = NSImage(named: "MocoIconTrayClosed")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        NSApp.setActivationPolicy(.prohibited)
        statusItem = NSStatusBar.system.statusItem(withLength: 30)
        
        if let button = statusItem?.button {
            button.image = openIcon
            button.action = #selector(togglePopover)
            button.target = self
            
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 350)
        var bookingView = BookingView()
        bookingView.delegate = self
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: bookingView)
        popover.behavior = .transient
        
        getLastBookingDate()
        print("AppDidFinishLaunching - Last Booking Date: \(String(describing: lastBookingDate))")
        
        startTimer() // Start the timer to check for blinking
    }
    
    @objc func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func startBlinking() {
        guard let button = statusItem?.button else { return }
        
        if !isBlinking {
            isBlinking = true
            print("startBlinking - Start Blinking")
        }
        
        blinkHold = Double.random(in: 0.5...5.0)
        print(blinkHold)
        
        DispatchQueue.main.async {
            button.image = self.closedIcon
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                button.image = self.openIcon
                
                //  Check the time *before* scheduling the next blink.
                let timeInterval = Date().timeIntervalSince(self.lastBookingDate ?? Date.distantPast)
                let minutesSinceLastBooking = timeInterval / 60
                
                if minutesSinceLastBooking >= 1 && self.isBlinking {
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.blinkHold) {
                        self.startBlinking() // Continue blinking if condition is still met
                    }
                } else {
                    self.stopBlinking() // Stop blinking if condition is not met
                }
            }
        }
    }
    
    func stopBlinking() {
        if let button = statusItem?.button {
            button.image = openIcon
        }
        isBlinking = false
        print("stopBlinking")
    }
    
    func startTimer() {
        // Use a timer to periodically check the booking time and start/stop blinking
        print("Last")
        timer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(checkLastBooking), userInfo: nil, repeats: true)
    }
    
    @objc func checkLastBooking() {
        guard let lastBookingDate = lastBookingDate else {
            startBlinking() // Start blinking if no booking date
            return
        }
        
        let timeInterval = Date().timeIntervalSince(lastBookingDate)
        let minutesSinceLastBooking = timeInterval / 60
        
        if minutesSinceLastBooking >= 120 {
            if !isBlinking { // Start blinking only if it's not already blinking
                startBlinking()
            }
            //Do nothing, blinking is handled by startBlinking
        } else {
            stopBlinking()
        }
    }
    
    func getLastBookingDate() {
        if let savedDate = UserDefaults.standard.value(forKey: "lastBookingDate") as? Date {
            self.lastBookingDate = savedDate
            print("getLastBookingDate - Retrieved Date: \(savedDate)")
        } else {
            self.lastBookingDate = nil
            print("getLastBookingDate - No Date Found")
        }
    }
    
    func didUpdateLastBookingDate(date: Date) {
        print("AppDelegate - Delegate method called with date: \(date)")
        self.lastBookingDate = date
        stopBlinking() // Stop blinking when a new booking is made
    }
    
    deinit {
        timer?.invalidate()
        print("AppDelegate - deinit")
    }
}

