/*
* The MIT License
*
* Copyright (c) 2016 halo
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
import CoreGraphics

// See /System/Library/Frameworks/Carbon.framework/Versions/A/Frameworks/HIToolbox.framework/Versions/A/Headers/Events.h

public enum KeyCode: CGKeyCode {
  
  case nullEvent = 0xFF
  
  case Keypad1 = 0x53
  case Keypad2 = 0x54
  case Keypad3 = 0x55
  case Keypad4 = 0x56
  case Keypad5 = 0x57
  case Keypad6 = 0x58
  
  case Keypad7 = 0x59
  case Keypad8 = 0x5B
  case Keypad9 = 0x5C
  case KeypadMultiply = 0x43
  case KeypadPlus = 0x45
  case KeypadDivide = 0x4B
  
  // Function keys for G-key mapping
  case KeyF13 = 0x69
  case KeyF14 = 0x6B
  case KeyF15 = 0x71
  case KeyF16 = 0x6A
  case KeyF17 = 0x40
  case KeyF18 = 0x4F
  
  // Letter keys A-Z (based on macOS CGKeyCode values)
  case KeyA = 0x00
  case KeyB = 0x0B
  case KeyC = 0x08
  case KeyD = 0x02
  case KeyE = 0x0E
  case KeyF = 0x03
  case KeyG = 0x05
  case KeyH = 0x04
  case KeyI = 0x22
  case KeyJ = 0x26
  case KeyK = 0x28
  case KeyL = 0x25
  case KeyM = 0x2E
  case KeyN = 0x2D
  case KeyO = 0x1F
  case KeyP = 0x23
  case KeyQ = 0x0C
  case KeyR = 0x0F
  case KeyS = 0x01
  case KeyT = 0x11
  case KeyU = 0x20
  case KeyV = 0x09
  case KeyW = 0x0D
  case KeyX = 0x07
  case KeyY = 0x10
  case KeyZ = 0x06
  
  // Number keys 0-9
  case Key0 = 0x1D
  case Key1 = 0x12
  case Key2 = 0x13
  case Key3 = 0x14
  case Key4 = 0x15
  case Key5 = 0x17
  case Key6 = 0x16
  case Key7 = 0x1A
  case Key8 = 0x1C
  case Key9 = 0x19
  
  // Special keys
  case KeySpace = 0x31
  case KeyEnter = 0x24
  case KeyTab = 0x30
  case KeyEscape = 0x35
  case KeyBackspace = 0x33
  case KeyDelete = 0x75
  
  // Arrow keys
  case KeyArrowUp = 0x7E
  case KeyArrowDown = 0x7D
  case KeyArrowLeft = 0x7B
  case KeyArrowRight = 0x7C
  
  // More function keys
  case KeyF1 = 0x7A
  case KeyF2 = 0x78
  case KeyF3 = 0x63
  case KeyF4 = 0x76
  case KeyF5 = 0x60
  case KeyF6 = 0x61
  case KeyF7 = 0x62
  case KeyF8 = 0x64
  case KeyF9 = 0x65
  case KeyF10 = 0x6D
  case KeyF11 = 0x67
  case KeyF12 = 0x6F
  
  // Common punctuation
  case KeySemicolon = 0x29
  case KeyComma = 0x2B
  case KeyPeriod = 0x2F
  case KeySlash = 0x2C
  case KeyBackslash = 0x2A
  case KeyQuote = 0x27
  case KeyLeftBracket = 0x21
  case KeyRightBracket = 0x1E
  case KeyMinus = 0x1B
  case KeyEqual = 0x18
  case KeyGrave = 0x32
  
}
