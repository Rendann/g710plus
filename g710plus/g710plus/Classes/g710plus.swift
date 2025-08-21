/*
* The MIT License
*
* Copyright (c) 2016 halo
* Based on the hard work by Eric Betts, see https://github.com/bettse/KuandoSwift
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import Foundation
import IOKit.hid
import CoreGraphics
import os.log

class G710plus : NSObject {
  
  static let version = G710PlusVersion
  let vendorId  = 0x046d  // Logitech
  let productId = 0xc24d  // G710+ Keyboard

  let reportSize = 16
  static let singleton = G710plus()
  static let logTimestamp: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
  }()
  
  static let logger = OSLog(subsystem: "com.halo.g710plus", category: "keyboard")
  var device : IOHIDDevice? = nil
  var reportBuffer : UnsafeMutablePointer<UInt8>? = nil
  var currentM : UInt8 = 0
  var g1IsPressed : Bool = false
  var g2IsPressed : Bool = false
  var g3IsPressed : Bool = false
  var g4IsPressed : Bool = false
  var g5IsPressed : Bool = false
  var g6IsPressed : Bool = false
  
  var currentMBitmask: UInt8 {
    switch (self.currentM) {
    case 1: return 0x10
    case 2: return 0x20
    case 3: return 0x40
    default: return 0
    }
  }
  

  func setM(number: UInt8) {
    self.currentM = number
    self.setMLight()
  }
  
  @objc func run() {
    logDebug("G710plus.run() called")
    
    // Log environment information
    logDebug("Working directory: \(FileManager.default.currentDirectoryPath)")
    logDebug("Bundle path: \(Bundle.main.bundlePath)")
    logDebug("HOME: \(ProcessInfo.processInfo.environment["HOME"] ?? "nil")")
    logDebug("PATH: \(ProcessInfo.processInfo.environment["PATH"] ?? "nil")")
    logDebug("Process name: \(ProcessInfo.processInfo.processName)")
    logDebug("Process ID: \(ProcessInfo.processInfo.processIdentifier)")
    
    logInfo("G710+ Utility Starting...")
    logInfo("Build: \(G710PlusBuild)")
    logDebug("Command line arguments: \(CommandLine.arguments)")
    logInfo("Starting G710plus daemon...")
    
    logDebug("Creating HID manager...")
    let deviceMatch = [kIOHIDProductIDKey: productId, kIOHIDVendorIDKey: vendorId ]
    let managerRef = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    logDebug("HID manager created, setting device matching...")
    IOHIDManagerSetDeviceMatching(managerRef, deviceMatch as CFDictionary)
    IOHIDManagerScheduleWithRunLoop(managerRef, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue);
    
    logDebug("Opening HID manager...")
    var openResult = IOHIDManagerOpen(managerRef, 0)
    if openResult != kIOReturnSuccess {
      logDebug("HID manager open failed, retrying...")
      // Try once more after a brief delay
      Thread.sleep(forTimeInterval: 1.0)
      openResult = IOHIDManagerOpen(managerRef, 0)
    }
    logDebug("HID manager open result: \(openResult)")
    
    let matchingCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
      let this : G710plus = unsafeBitCast(inContext, to: G710plus.self)
      this.connected(inResult: inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
    }
    
    let removalCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
      let this : G710plus = unsafeBitCast(inContext, to: G710plus.self)
      this.removed(inResult: inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
    }
    
    logDebug("Registering HID callbacks...")
    IOHIDManagerRegisterDeviceMatchingCallback(managerRef, matchingCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    IOHIDManagerRegisterDeviceRemovalCallback(managerRef, removalCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    
    if openResult != kIOReturnSuccess {
      logInfo("WARNING: IOHIDManager failed to open")
    }
    
    logDebug("Entering G710plus RunLoop...")
    RunLoop.current.run();
  }

  func connected(inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
    logInfo("G710+ keyboard connected")
    
    reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
    device = inIOHIDDeviceRef
    
    // Open the device before attempting any operations
    let openResult = IOHIDDeviceOpen(device!, IOOptionBits(kIOHIDOptionsTypeNone))
    if openResult != kIOReturnSuccess {
      logInfo("Warning: Failed to open device (\(openResult))")
    }
    
    let inputCallback : IOHIDReportCallback = { inContext, inResult, inSender, type, reportId, report, reportLength in
      let this : G710plus = unsafeBitCast(inContext, to: G710plus.self)
      this.input(inResult: inResult, inSender: inSender!, type: type, reportId: reportId, report: report, reportLength: reportLength)
    }
    
    //Hook up inputcallback
    IOHIDDeviceRegisterInputReportCallback(device!, reportBuffer!, reportSize, inputCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))

    self.deactivateGhosting()
    self.setM(number: 1);
  }
  
  func removed(inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
    logInfo("G710+ removed")
    
    // Close the device if it's open
    if device != nil {
      let closeResult = IOHIDDeviceClose(device!, IOOptionBits(kIOHIDOptionsTypeNone))
      if closeResult == kIOReturnSuccess {
        logDebug("Device closed successfully")
      }
      device = nil
    }
    
    if let buffer = reportBuffer {
      buffer.deallocate()
      reportBuffer = nil
    }
    //NSNotificationCenter.defaultCenter().postNotificationName("deviceDisconnected", object: nil, userInfo: ["class": NSStringFromClass(self.dynamicType)])
  }
  
  
  func controlTransfer(address: CFIndex, bytes: [UInt8]) {
    guard let G710plus = device else { 
      logDebug("Control transfer failed: device is nil")
      return 
    }
    let data = Data(bytes)
    
    var result: IOReturn = kIOReturnError
    data.withUnsafeBytes { bytes in
      result = IOHIDDeviceSetReport(G710plus, kIOHIDReportTypeFeature, address, bytes.bindMemory(to: UInt8.self).baseAddress!, data.count)
    }
    
    // Log only failures and only if verbose
    if result != kIOReturnSuccess {
      logDebug("Control transfer failed: \(result)")
    }
  }
  

  func setMLight() {
    self.controlTransfer(address: 0x0306, bytes: [0x06, self.currentMBitmask])
  }

  func deactivateGhosting() {
    self.controlTransfer(address: 0x0309, bytes: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
  }

  func input(inResult: IOReturn, inSender: UnsafeMutableRawPointer, type: IOHIDReportType, reportId: UInt32, report: UnsafeMutablePointer<UInt8>, reportLength: CFIndex) {

    // Validate report length to prevent buffer overflow
    if (reportLength <= 0 || reportLength > reportSize) {
      return
    }

    // So the keyboard tells us that a key event happened.
    // Converting the data pointer to an Integer so we can interpret it.
    let message = Data(bytes: report, count: reportLength)
    var keyCode: UInt32 = 0
    _ = message.withUnsafeBytes { bytes in
      memcpy(&keyCode, bytes.baseAddress, min(MemoryLayout<UInt32>.size, reportLength))
    }
    
    // For some reason the G710+ constantly sends empty key events.
    // We'll just ignore those.
    if (keyCode == 0) { return }
    
    
    switch (keyCode) {
      
    // See if one of the M-keys was pressed
    case 0x100003:
      self.setM(number: 1)
    case 0x200003:
      self.setM(number: 2)
    case 0x400003:
      self.setM(number: 3)
    
    // See if one of the G-keys was pressed
    case 0x103:
      if (!g1IsPressed) {
        logDebug("You pressed G1 (down)")
        g1IsPressed = true
        // Send Ctrl+Shift+F1 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF13, modifiers: [], keyDown: true)
      }
    case 0x203:
      if (!g2IsPressed) {
        logDebug("You pressed G2 (down)")
        g2IsPressed = true
        // Send Ctrl+Shift+F2 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF14, modifiers: [], keyDown: true)
      }
    case 0x403:
      if (!g3IsPressed) {
        logDebug("You pressed G3 (down)")
        g3IsPressed = true
        // Send Ctrl+Shift+F3 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF15, modifiers: [], keyDown: true)
      }
    case 0x803:
      if (!g4IsPressed) {
        logDebug("You pressed G4 (down)")
        g4IsPressed = true
        // Send Ctrl+Shift+F4 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF16, modifiers: [], keyDown: true)
      }
    case 0x1003:
      if (!g5IsPressed) {
        logDebug("You pressed G5 (down)")
        g5IsPressed = true
        // Send Ctrl+Shift+F5 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF17, modifiers: [], keyDown: true)
      }
    case 0x2003:
      if (!g6IsPressed) {
        logDebug("You pressed G6 (down)")
        g6IsPressed = true
        // Send Ctrl+Shift+F6 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF18, modifiers: [], keyDown: true)
      }
    case 0x3:
      // Handle release for any G-key that was pressed
      if (g1IsPressed) {
        logDebug("You released G1 (up)")
        g1IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF13, modifiers: [], keyDown: false)
      }
      if (g2IsPressed) {
        logDebug("You released G2 (up)")
        g2IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF14, modifiers: [], keyDown: false)
      }
      if (g3IsPressed) {
        logDebug("You released G3 (up)")
        g3IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF15, modifiers: [], keyDown: false)
      }
      if (g4IsPressed) {
        logDebug("You released G4 (up)")
        g4IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF16, modifiers: [], keyDown: false)
      }
      if (g5IsPressed) {
        logDebug("You released G5 (up)")
        g5IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF17, modifiers: [], keyDown: false)
      }
      if (g6IsPressed) {
        logDebug("You released G6 (up)")
        g6IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF18, modifiers: [], keyDown: false)
      }

    default: break
    }
}
  
  
  func sendKeyEvent(keyCode: KeyCode, modifiers: CGEventFlags, keyDown: Bool) {
    logDebug("sendKeyEvent called - keyCode: \(keyCode.rawValue), keyDown: \(keyDown)")
    if (keyCode == KeyCode.nullEvent) { 
      logDebug("Null event, returning")
      return 
    }
    
    let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
    logDebug("CGEventSource created: \(source != nil ? "success" : "FAILED")")
    
    let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode.rawValue, keyDown: keyDown)
    logDebug("CGEvent created: \(event != nil ? "success" : "FAILED")")
    
    if let event = event {
      event.flags = modifiers
      let location = CGEventTapLocation.cghidEventTap
      event.post(tap: location)
      logDebug("Event posted successfully")
    } else {
      logInfo("ERROR - CGEvent is nil, cannot post!")
    }
  }
  
  func logDebug(_ message: String) {
    #if VERBOSE_LOGGING
    os_log("%{public}@", log: G710plus.logger, type: .debug, message)
    #endif
  }
  
  func logInfo(_ message: String) {
    os_log("%{public}@", log: G710plus.logger, type: .info, message)
  }
  
}
