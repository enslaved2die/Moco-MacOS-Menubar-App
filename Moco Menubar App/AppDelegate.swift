import Cocoa
import SwiftUI
import AppKit

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate, BookingDelegate { // 4. Implement the delegate
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var isIconVisible: Bool = true
    var timer: Timer?
    var lastBookingDate: Date?
    
    let openIcon = NSImage(named: "MocoIconTray")
    let closedIcon = NSImage(named: "MocoIconTrayClosed")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        NSApp.setActivationPolicy(.prohibited)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = openIcon
            button.action = #selector(togglePopover)
            
        }
        
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 350)
        // Use the existing BookingView
        var bookingView = BookingView() // Changed to var
        // 5. Set the delegate
        bookingView.delegate = self
        popover.contentViewController = NSViewController()
        popover.contentViewController?.view = NSHostingView(rootView: bookingView)
        popover.behavior = .transient
        
        // Get the last booking date
        getLastBookingDate()
        print("AppDidFinishLaunching - Last Booking Date: \(String(describing: lastBookingDate))")
        
        // Start the timer to check for inactivity
        startTimer()
    }
    
    @objc func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func startBlinking() {
        if timer == nil { // Check if timer is already running
            let randomInterval = Double.random(in: 3.0...10.0)
            timer = Timer.scheduledTimer(withTimeInterval: randomInterval, repeats: true) { [weak self] _ in
                guard let self = self, let button = self.statusItem.button else { return }
                
                DispatchQueue.main.async {
                    button.image = self.closedIcon
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        button.image = self.openIcon
                    }
                }
            }
            print("startBlinking - Timer started")
        } else {
            print("startBlinking - Timer already running")
        }
    }
    
    func stopBlinking() {
        timer?.invalidate()
        timer = nil
        if let button = statusItem.button {
            button.image = openIcon
        }
        print("stopBlinking - Timer stopped")
    }
    
    func startTimer() {
        Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(checkLastBooking), userInfo: nil, repeats: true)
    }
    
    @objc func checkLastBooking() {
        guard let lastBookingDate = lastBookingDate else {
            startBlinking()
            return
        }
        
        let timeInterval = Date().timeIntervalSince(lastBookingDate)
        print("checkLastBooking - Time Interval: \(timeInterval)")
        let minutesSinceLastBooking = timeInterval / 60
        print("checkLastBooking - Minutes Since Last Booking: \(minutesSinceLastBooking)")
        
        if minutesSinceLastBooking >= 120 {
            startBlinking()
        } else {
            stopBlinking()
        }
    }
    
    func getLastBookingDate() {
        if let savedDate = UserDefaults.standard.value(forKey: "lastBookingDate") as? Date {
            self.lastBookingDate = savedDate
            print("getLastBookingDate - Retrieved Date: \(savedDate)")
        } else {
            self.lastBookingDate = nil;
            print("getLastBookingDate - No Date Found")
        }
    }
    
    deinit {
        timer?.invalidate()
        print("AppDelegate - deinit")
    }
    
    // 6. Implement the delegate method
    func didUpdateLastBookingDate(date: Date) {
        print("AppDelegate - Delegate method called with date: \(date)")
        self.lastBookingDate = date
        stopBlinking() // Stop blinking when a new booking is made
    }
}

