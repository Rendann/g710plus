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

class G710plus : NSObject {
  
  let vendorId  = 0x046d  // Logitech
  let productId = 0xc24d  // G710+ Keyboard

  let reportSize = 16
  static let singleton = G710plus()
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
  
  var G1AliasKey: KeyCode {
    switch (self.currentM) {
    case 1 : return KeyCode.Keypad1
    case 2 : return KeyCode.Keypad7
    default: return KeyCode.nullEvent
    }
  }

  var G2AliasKey: KeyCode {
    switch (self.currentM) {
    case 1 : return KeyCode.Keypad2
    case 2 : return KeyCode.Keypad8
    default: return KeyCode.nullEvent
    }
  }

  var G3AliasKey: KeyCode {
    switch (self.currentM) {
    case 1 : return KeyCode.Keypad3
    case 2 : return KeyCode.Keypad9
    default: return KeyCode.nullEvent
    }
  }

  var G4AliasKey: KeyCode {
    switch (self.currentM) {
    case 1 : return KeyCode.Keypad4
    case 2 : return KeyCode.KeypadMultiply
    default: return KeyCode.nullEvent
    }
  }

  var G5AliasKey: KeyCode {
    switch (self.currentM) {
    case 1 : return KeyCode.Keypad5
    case 2 : return KeyCode.KeypadPlus
    default: return KeyCode.nullEvent
    }
  }

  var G6AliasKey: KeyCode {
    switch (self.currentM) {
    case 1 : return KeyCode.Keypad6
    case 2 : return KeyCode.KeypadDivide
    default: return KeyCode.nullEvent
    }
  }

  func setM(number: UInt8) {
    self.currentM = number
    self.setMLight()
  }
  
  @objc func run() {
    log(message: "Starting G710plus daemon...")
    
    let deviceMatch = [kIOHIDProductIDKey: productId, kIOHIDVendorIDKey: vendorId ]
    let managerRef = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    IOHIDManagerSetDeviceMatching(managerRef, deviceMatch as CFDictionary)
    IOHIDManagerScheduleWithRunLoop(managerRef, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue);
    
    var openResult = IOHIDManagerOpen(managerRef, 0)
    if openResult != kIOReturnSuccess {
      // Try once more after a brief delay
      Thread.sleep(forTimeInterval: 1.0)
      openResult = IOHIDManagerOpen(managerRef, 0)
    }
    
    let matchingCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
      let this : G710plus = unsafeBitCast(inContext, to: G710plus.self)
      this.connected(inResult: inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
    }
    
    let removalCallback : IOHIDDeviceCallback = { inContext, inResult, inSender, inIOHIDDeviceRef in
      let this : G710plus = unsafeBitCast(inContext, to: G710plus.self)
      this.removed(inResult: inResult, inSender: inSender!, inIOHIDDeviceRef: inIOHIDDeviceRef)
    }
    
    IOHIDManagerRegisterDeviceMatchingCallback(managerRef, matchingCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    IOHIDManagerRegisterDeviceRemovalCallback(managerRef, removalCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))
    
    if openResult != kIOReturnSuccess {
      log(message: "WARNING: IOHIDManager failed to open")
    }
    
    
    RunLoop.current.run();
  }

  func connected(inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
    log(message: "G710+ keyboard connected")
    
    reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: reportSize)
    device = inIOHIDDeviceRef
    
    // Open the device before attempting any operations
    let openResult = IOHIDDeviceOpen(device!, IOOptionBits(kIOHIDOptionsTypeNone))
    if openResult != kIOReturnSuccess {
      log(message: "Warning: Failed to open device (\(openResult))")
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
    log(message: "G710+ removed")
    
    // Close the device if it's open
    if device != nil {
      let closeResult = IOHIDDeviceClose(device!, IOOptionBits(kIOHIDOptionsTypeNone))
      if closeResult == kIOReturnSuccess {
        log(message: "Device closed successfully")
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
    guard let G710plus = device else { return }
    let data = Data(bytes)
    
    // Ensure device is open
    IOHIDDeviceOpen(G710plus, IOOptionBits(kIOHIDOptionsTypeNone))
    
    var result: IOReturn = kIOReturnError
    data.withUnsafeBytes { bytes in
      result = IOHIDDeviceSetReport(G710plus, kIOHIDReportTypeFeature, address, bytes.bindMemory(to: UInt8.self).baseAddress!, data.count)
    }
    
    // Log only failures and only if verbose
    if result != kIOReturnSuccess {
      log(message: "Control transfer failed: \(result)")
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
        print("You pressed G1 (down)")
        g1IsPressed = true
        // Send Ctrl+Shift+F1 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF13, modifiers: [], keyDown: true)
      }
    case 0x203:
      if (!g2IsPressed) {
        print("You pressed G2 (down)")
        g2IsPressed = true
        // Send Ctrl+Shift+F2 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF14, modifiers: [], keyDown: true)
      }
    case 0x403:
      if (!g3IsPressed) {
        print("You pressed G3 (down)")
        g3IsPressed = true
        // Send Ctrl+Shift+F3 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF15, modifiers: [], keyDown: true)
      }
    case 0x803:
      if (!g4IsPressed) {
        print("You pressed G4 (down)")
        g4IsPressed = true
        // Send Ctrl+Shift+F4 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF16, modifiers: [], keyDown: true)
      }
    case 0x1003:
      if (!g5IsPressed) {
        print("You pressed G5 (down)")
        g5IsPressed = true
        // Send Ctrl+Shift+F5 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF17, modifiers: [], keyDown: true)
      }
    case 0x2003:
      if (!g6IsPressed) {
        print("You pressed G6 (down)")
        g6IsPressed = true
        // Send Ctrl+Shift+F6 key down
        self.sendKeyEvent(keyCode: KeyCode.KeyF18, modifiers: [], keyDown: true)
      }
    case 0x3:
      // Handle release for any G-key that was pressed
      if (g1IsPressed) {
        print("You released G1 (up)")
        g1IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF13, modifiers: [], keyDown: false)
      }
      if (g2IsPressed) {
        print("You released G2 (up)")
        g2IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF14, modifiers: [], keyDown: false)
      }
      if (g3IsPressed) {
        print("You released G3 (up)")
        g3IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF15, modifiers: [], keyDown: false)
      }
      if (g4IsPressed) {
        print("You released G4 (up)")
        g4IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF16, modifiers: [], keyDown: false)
      }
      if (g5IsPressed) {
        print("You released G5 (up)")
        g5IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF17, modifiers: [], keyDown: false)
      }
      if (g6IsPressed) {
        print("You released G6 (up)")
        g6IsPressed = false
        self.sendKeyEvent(keyCode: KeyCode.KeyF18, modifiers: [], keyDown: false)
      }

    default: break
    }
}
  
  
  func sendKeyEvent(keyCode: KeyCode, modifiers: CGEventFlags, keyDown: Bool) {
    if (keyCode == KeyCode.nullEvent) { return }
    
    let source = CGEventSource(stateID: CGEventSourceStateID.hidSystemState)
    let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode.rawValue, keyDown: keyDown)
    event?.flags = modifiers
    let location = CGEventTapLocation.cghidEventTap

    event?.post(tap: location)
  }
  
  func log(message: String) {
    if CommandLine.arguments.contains("--verbose") {
      let timestamp = DateFormatter()
      timestamp.dateFormat = "yyyy-MM-dd HH:mm:ss"
      print("[\(timestamp.string(from: Date()))] \(message)")
      fflush(stdout)
    }
  }
  
}
