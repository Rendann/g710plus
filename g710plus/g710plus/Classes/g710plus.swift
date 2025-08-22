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
  
  // Constants for timing
  private static let keyPressDelay: TimeInterval = 0.01 // 10ms key press duration
  private static let stepDelay: TimeInterval = 0.05 // 50ms delay between steps
  
  // Constants for HID event codes
  private static let m1KeyCode: UInt32 = 0x100003
  private static let m2KeyCode: UInt32 = 0x200003
  private static let m3KeyCode: UInt32 = 0x400003
  
  private static let g1KeyDownCode: UInt32 = 0x103
  private static let g2KeyDownCode: UInt32 = 0x203
  private static let g3KeyDownCode: UInt32 = 0x403
  private static let g4KeyDownCode: UInt32 = 0x803
  private static let g5KeyDownCode: UInt32 = 0x1003
  private static let g6KeyDownCode: UInt32 = 0x2003
  private static let gKeyUpCode: UInt32 = 0x3
  
  private static let validGKeys = Set(["g1", "g2", "g3", "g4", "g5", "g6"])
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
  
  // Track currently held keys for each G-key (keyCode and modifiers)
  private var heldKeys: [String: (keyCode: KeyCode, modifiers: CGEventFlags)] = [:]
  private let heldKeysQueue = DispatchQueue(label: "com.halo.g710plus.heldKeys", qos: .userInitiated)
  
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
    guard let device = device else {
      logInfo("ERROR - Device is nil, cannot open")
      return
    }
    
    let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
    if openResult != kIOReturnSuccess {
      logInfo("Warning: Failed to open device (\(openResult))")
    }
    
    let inputCallback : IOHIDReportCallback = { inContext, inResult, inSender, type, reportId, report, reportLength in
      let this : G710plus = unsafeBitCast(inContext, to: G710plus.self)
      this.input(inResult: inResult, inSender: inSender!, type: type, reportId: reportId, report: report, reportLength: reportLength)
    }
    
    //Hook up inputcallback
    guard let reportBuffer = reportBuffer else {
      logInfo("ERROR - Report buffer is nil, cannot register callback")
      return
    }
    
    IOHIDDeviceRegisterInputReportCallback(device, reportBuffer, reportSize, inputCallback, unsafeBitCast(self, to: UnsafeMutableRawPointer.self))

    self.deactivateGhosting()
    self.setM(number: 1);
  }
  
  func removed(inResult: IOReturn, inSender: UnsafeMutableRawPointer, inIOHIDDeviceRef: IOHIDDevice!) {
    logInfo("G710+ removed")
    
    // Close the device if it's open
    if let device = device {
      let closeResult = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
      if closeResult == kIOReturnSuccess {
        logDebug("Device closed successfully")
      } else {
        logDebug("Warning: Device close failed (\(closeResult))")
      }
      self.device = nil
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
    
    
    switch keyCode {
      
    // See if one of the M-keys was pressed
    case G710plus.m1KeyCode:
      self.setM(number: 1)
    case G710plus.m2KeyCode:
      self.setM(number: 2)
    case G710plus.m3KeyCode:
      self.setM(number: 3)
    
    // See if one of the G-keys was pressed
    case G710plus.g1KeyDownCode:
      if !g1IsPressed {
        logDebug("You pressed G1 (down)")
        g1IsPressed = true
        self.sendConfiguredKeyEvent(for: "g1", keyDown: true)
      }
    case G710plus.g2KeyDownCode:
      if !g2IsPressed {
        logDebug("You pressed G2 (down)")
        g2IsPressed = true
        self.sendConfiguredKeyEvent(for: "g2", keyDown: true)
      }
    case G710plus.g3KeyDownCode:
      if !g3IsPressed {
        logDebug("You pressed G3 (down)")
        g3IsPressed = true
        self.sendConfiguredKeyEvent(for: "g3", keyDown: true)
      }
    case G710plus.g4KeyDownCode:
      if !g4IsPressed {
        logDebug("You pressed G4 (down)")
        g4IsPressed = true
        self.sendConfiguredKeyEvent(for: "g4", keyDown: true)
      }
    case G710plus.g5KeyDownCode:
      if !g5IsPressed {
        logDebug("You pressed G5 (down)")
        g5IsPressed = true
        self.sendConfiguredKeyEvent(for: "g5", keyDown: true)
      }
    case G710plus.g6KeyDownCode:
      if !g6IsPressed {
        logDebug("You pressed G6 (down)")
        g6IsPressed = true
        self.sendConfiguredKeyEvent(for: "g6", keyDown: true)
      }
    case G710plus.gKeyUpCode:
      // Handle release for any G-key that was pressed
      if (g1IsPressed) {
        logDebug("You released G1 (up)")
        g1IsPressed = false
        self.sendConfiguredKeyEvent(for: "g1", keyDown: false)
      }
      if (g2IsPressed) {
        logDebug("You released G2 (up)")
        g2IsPressed = false
        self.sendConfiguredKeyEvent(for: "g2", keyDown: false)
      }
      if (g3IsPressed) {
        logDebug("You released G3 (up)")
        g3IsPressed = false
        self.sendConfiguredKeyEvent(for: "g3", keyDown: false)
      }
      if (g4IsPressed) {
        logDebug("You released G4 (up)")
        g4IsPressed = false
        self.sendConfiguredKeyEvent(for: "g4", keyDown: false)
      }
      if (g5IsPressed) {
        logDebug("You released G5 (up)")
        g5IsPressed = false
        self.sendConfiguredKeyEvent(for: "g5", keyDown: false)
      }
      if (g6IsPressed) {
        logDebug("You released G6 (up)")
        g6IsPressed = false
        self.sendConfiguredKeyEvent(for: "g6", keyDown: false)
      }

    default: break
    }
}
  
  
  func sendConfiguredKeyEvent(for gKey: String, keyDown: Bool) {
    guard let mapping = ConfigurationManager.shared.getKeyMapping(for: gKey) else {
      logInfo("ERROR - No configuration found for \(gKey)")
      return
    }
    
    if keyDown {
      // Execute key sequence on key down
      self.executeKeySequence(mapping: mapping, gKey: gKey)
    } else {
      // Release the final held key on key up
      self.releaseFinalKey(for: gKey)
    }
  }
  
  func sendKeyEvent(keyCode: KeyCode, modifiers: CGEventFlags, keyDown: Bool) {
    logDebug("sendKeyEvent called - keyCode: \(keyCode.rawValue), keyDown: \(keyDown)")
    
    // Validate keyCode is within valid range
    guard keyCode != KeyCode.nullEvent else {
      logDebug("Null event, returning")
      return 
    }
    
    // Additional bounds checking for CGKeyCode
    guard keyCode.rawValue <= 0xFF else {
      logInfo("ERROR - Invalid keyCode: \(keyCode.rawValue) exceeds maximum value")
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
  
  func executeKeySequence(mapping: KeyMapping, gKey: String) {
    let keys = mapping.keys
    
    if keys.isEmpty {
      logInfo("ERROR - No keys found for \(gKey)")
      return
    }
    
    logDebug("Executing key sequence for \(gKey) with \(keys.count) steps")
    
    // Execute sequence with proper async timing
    executeKeyStep(keys: keys, index: 0, gKey: gKey)
  }
  
  private func executeKeyStep(keys: [SequenceStep], index: Int, gKey: String) {
    guard index < keys.count else { return }
    
    let step = keys[index]
    let result = step.toKeyCodeAndModifiers()
    
    guard let keyCode = result.keyCode else {
      logInfo("ERROR - Invalid key in step \(index + 1) for \(gKey): '\(step.key)'")
      return
    }
    
    let modifiers = result.modifiers
    let isLastStep = (index == keys.count - 1)
    
    logDebug("Key sequence step \(index + 1)/\(keys.count): \(step.key)" + (isLastStep ? " (final - will hold)" : ""))
    
    // Send key down
    sendKeyEvent(keyCode: keyCode, modifiers: modifiers, keyDown: true)
    
    if isLastStep {
      // For the final key, store it so we can release it later
      heldKeysQueue.sync { [weak self] in
        self?.heldKeys[gKey.lowercased()] = (keyCode, modifiers)
      }
    } else {
      // For intermediate keys, complete the press/release cycle with non-blocking delay
      DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + G710plus.keyPressDelay) { [weak self] in
        guard let self = self else { return }
        
        // Send key up
        self.sendKeyEvent(keyCode: keyCode, modifiers: modifiers, keyDown: false)
        
        // Continue to next step after delay
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + G710plus.stepDelay) {
          self.executeKeyStep(keys: keys, index: index + 1, gKey: gKey)
        }
      }
      return // Exit early to avoid immediate continuation
    }
    
    // If this was the last step, we're done
  }
  
  
  func releaseFinalKey(for gKey: String) {
    let normalizedKey = gKey.lowercased()
    guard G710plus.validGKeys.contains(normalizedKey) else {
      logInfo("ERROR - Invalid G-key identifier: \(gKey)")
      return
    }
    
    heldKeysQueue.sync { [weak self] in
      guard let self = self else { return }
      
      if let heldKey = self.heldKeys[normalizedKey] {
        self.logDebug("Releasing final key for \(gKey): \(heldKey.keyCode.rawValue)")
        
        // Release the key on the main queue to ensure proper event ordering
        DispatchQueue.main.async {
          self.sendKeyEvent(keyCode: heldKey.keyCode, modifiers: heldKey.modifiers, keyDown: false)
          
          // After releasing held key, execute onRelease sequence if present
          self.executeReleaseSequence(for: gKey)
        }
        
        // Remove from held keys
        self.heldKeys.removeValue(forKey: normalizedKey)
      } else {
        self.logDebug("No held key found for \(gKey) to release")
        
        // Still execute onRelease sequence even if no held key
        DispatchQueue.main.async {
          self.executeReleaseSequence(for: gKey)
        }
      }
    }
  }
  
  private func executeReleaseSequence(for gKey: String) {
    guard let mapping = ConfigurationManager.shared.getKeyMapping(for: gKey),
          let onRelease = mapping.onRelease,
          !onRelease.isEmpty else {
      logDebug("No onRelease sequence for \(gKey)")
      return
    }
    
    logDebug("Executing onRelease sequence for \(gKey) with \(onRelease.count) steps")
    
    // Execute release sequence with proper async timing (all keys are tapped)
    executeReleaseStep(steps: onRelease, index: 0, gKey: gKey)
  }
  
  private func executeReleaseStep(steps: [SequenceStep], index: Int, gKey: String) {
    guard index < steps.count else { return }
    
    let step = steps[index]
    let result = step.toKeyCodeAndModifiers()
    
    guard let keyCode = result.keyCode else {
      logInfo("ERROR - Invalid key in onRelease step \(index + 1) for \(gKey): '\(step.key)'")
      return
    }
    
    let modifiers = result.modifiers
    
    logDebug("OnRelease step \(index + 1)/\(steps.count): \(step.key)")
    
    // Send key down
    sendKeyEvent(keyCode: keyCode, modifiers: modifiers, keyDown: true)
    
    // For release sequences, all keys are tapped (no holding)
    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + G710plus.keyPressDelay) { [weak self] in
      guard let self = self else { return }
      
      // Send key up
      self.sendKeyEvent(keyCode: keyCode, modifiers: modifiers, keyDown: false)
      
      // Continue to next step after delay
      if index < steps.count - 1 {
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + G710plus.stepDelay) {
          self.executeReleaseStep(steps: steps, index: index + 1, gKey: gKey)
        }
      }
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
