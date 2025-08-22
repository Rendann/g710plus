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

struct GKeyConfiguration: Codable {
    let g1: KeyMapping
    let g2: KeyMapping
    let g3: KeyMapping
    let g4: KeyMapping
    let g5: KeyMapping
    let g6: KeyMapping
    
    static let defaultConfiguration = GKeyConfiguration(
        g1: KeyMapping(key: "l", modifiers: ["control", "command", "shift"]),
        g2: KeyMapping(key: "k", modifiers: ["control", "command", "shift"]),
        g3: KeyMapping(key: "j", modifiers: ["control", "command", "shift"]),
        g4: KeyMapping(keys: [SequenceStep(key: "F6"), SequenceStep(key: "F18")]),
        g5: KeyMapping(key: "F17"),
        g6: KeyMapping(key: "F18")
    )
    
    func getMapping(for gKey: String) -> KeyMapping? {
        switch gKey.lowercased() {
        case "g1": return g1
        case "g2": return g2
        case "g3": return g3
        case "g4": return g4
        case "g5": return g5
        case "g6": return g6
        default: return nil
        }
    }
}

struct SequenceStep: Codable {
    let key: String
    let modifiers: [String]
    
    init(key: String, modifiers: [String] = []) {
        self.key = key
        self.modifiers = modifiers
    }
    
    func toKeyCodeAndModifiers() -> (keyCode: KeyCode?, modifiers: CGEventFlags) {
        let result = KeyCode.fromCharacter(key)
        var flags: CGEventFlags = []
        
        // Add user-defined modifiers
        for modifier in modifiers {
            switch modifier.lowercased() {
            case "control", "ctrl":
                flags.insert(.maskControl)
            case "command", "cmd":
                flags.insert(.maskCommand)
            case "shift":
                flags.insert(.maskShift)
            case "option", "alt":
                flags.insert(.maskAlternate)
            default:
                continue
            }
        }
        
        return (result.keyCode, flags)
    }
}

struct KeyMapping: Codable {
    let keys: [SequenceStep]
    let onRelease: [SequenceStep]?
    
    init(keys: [SequenceStep], onRelease: [SequenceStep]? = nil) {
        self.keys = keys
        self.onRelease = onRelease
    }
    
    // Convenience initializer for single key (for code compatibility)
    init(key: String, modifiers: [String] = []) {
        self.keys = [SequenceStep(key: key, modifiers: modifiers)]
        self.onRelease = nil
    }
    
    func isSequence() -> Bool {
        return keys.count > 1
    }
    
    func validate() -> (isValid: Bool, errorMessage: String?) {
        // Must have at least one key
        if keys.isEmpty {
            return (false, "KeyMapping must specify at least one key in 'keys' array")
        }
        
        // Validate each key in the main sequence
        for (index, step) in keys.enumerated() {
            let result = KeyCode.fromCharacter(step.key)
            if result.keyCode == nil {
                if step.key.count == 1, let char = step.key.first, char >= "A" && char <= "Z" {
                    return (false, "Key \(index + 1): Uppercase letter '\(step.key)' not allowed. Use '\(step.key.lowercased())' with \"shift\" modifier instead.")
                } else {
                    return (false, "Key \(index + 1): Invalid key '\(step.key)'")
                }
            }
            
            // Validate step modifiers
            for modifier in step.modifiers {
                let lowered = modifier.lowercased()
                if !["control", "ctrl", "command", "cmd", "shift", "option", "alt"].contains(lowered) {
                    return (false, "Key \(index + 1): Invalid modifier '\(modifier)'")
                }
            }
        }
        
        // Validate onRelease sequence if present
        if let onRelease = onRelease {
            for (index, step) in onRelease.enumerated() {
                let result = KeyCode.fromCharacter(step.key)
                if result.keyCode == nil {
                    if step.key.count == 1, let char = step.key.first, char >= "A" && char <= "Z" {
                        return (false, "OnRelease key \(index + 1): Uppercase letter '\(step.key)' not allowed. Use '\(step.key.lowercased())' with \"shift\" modifier instead.")
                    } else {
                        return (false, "OnRelease key \(index + 1): Invalid key '\(step.key)'")
                    }
                }
                
                // Validate step modifiers
                for modifier in step.modifiers {
                    let lowered = modifier.lowercased()
                    if !["control", "ctrl", "command", "cmd", "shift", "option", "alt"].contains(lowered) {
                        return (false, "OnRelease key \(index + 1): Invalid modifier '\(modifier)'")
                    }
                }
            }
        }
        
        return (true, nil)
    }
    
}

extension KeyCode {
    static func fromCharacter(_ input: String) -> (keyCode: KeyCode?, needsShift: Bool) {
        // Handle single characters (letters, numbers, punctuation)
        if input.count == 1 {
            let char = input.first!
            
            // Lowercase letters
            if char >= "a" && char <= "z" {
                let keyCode = letterToKeyCode(char.uppercased().first!)
                return (keyCode, false)
            }
            
            // Uppercase letters not allowed - must use lowercase + shift modifier
            if char >= "A" && char <= "Z" {
                return (nil, false)
            }
            
            // Numbers and shifted number symbols
            if char >= "0" && char <= "9" {
                let keyCode = numberToKeyCode(char)
                return (keyCode, false)
            }
            
            // Punctuation (base characters only - use explicit shift modifier for shifted symbols)
            switch char {
            case ";": return (.KeySemicolon, false)
            case ",": return (.KeyComma, false)
            case ".": return (.KeyPeriod, false)
            case "/": return (.KeySlash, false)
            case "\\": return (.KeyBackslash, false)
            case "'": return (.KeyQuote, false)
            case "[": return (.KeyLeftBracket, false)
            case "]": return (.KeyRightBracket, false)
            case "-": return (.KeyMinus, false)
            case "=": return (.KeyEqual, false)
            case "`": return (.KeyGrave, false)
            default: break
            }
        }
        
        // Handle special key names
        switch input {
        // Special keys
        case "Space": return (.KeySpace, false)
        case "Enter": return (.KeyEnter, false)
        case "Tab": return (.KeyTab, false)
        case "Escape": return (.KeyEscape, false)
        case "Backspace": return (.KeyBackspace, false)
        case "Delete": return (.KeyDelete, false)
        
        // Arrow keys
        case "ArrowUp": return (.KeyArrowUp, false)
        case "ArrowDown": return (.KeyArrowDown, false)
        case "ArrowLeft": return (.KeyArrowLeft, false)
        case "ArrowRight": return (.KeyArrowRight, false)
        
        // Function keys F1-F12
        case "F1": return (.KeyF1, false)
        case "F2": return (.KeyF2, false)
        case "F3": return (.KeyF3, false)
        case "F4": return (.KeyF4, false)
        case "F5": return (.KeyF5, false)
        case "F6": return (.KeyF6, false)
        case "F7": return (.KeyF7, false)
        case "F8": return (.KeyF8, false)
        case "F9": return (.KeyF9, false)
        case "F10": return (.KeyF10, false)
        case "F11": return (.KeyF11, false)
        case "F12": return (.KeyF12, false)
        
        // Extended function keys
        case "F13": return (.KeyF13, false)
        case "F14": return (.KeyF14, false)
        case "F15": return (.KeyF15, false)
        case "F16": return (.KeyF16, false)
        case "F17": return (.KeyF17, false)
        case "F18": return (.KeyF18, false)
        
        // Keypad keys
        case "Keypad1": return (.Keypad1, false)
        case "Keypad2": return (.Keypad2, false)
        case "Keypad3": return (.Keypad3, false)
        case "Keypad4": return (.Keypad4, false)
        case "Keypad5": return (.Keypad5, false)
        case "Keypad6": return (.Keypad6, false)
        case "Keypad7": return (.Keypad7, false)
        case "Keypad8": return (.Keypad8, false)
        case "Keypad9": return (.Keypad9, false)
        case "KeypadMultiply": return (.KeypadMultiply, false)
        case "KeypadPlus": return (.KeypadPlus, false)
        case "KeypadDivide": return (.KeypadDivide, false)
        
        
        default:
            return (nil, false)
        }
    }
    
    private static func letterToKeyCode(_ char: Character) -> KeyCode? {
        switch char {
        case "A": return .KeyA
        case "B": return .KeyB
        case "C": return .KeyC
        case "D": return .KeyD
        case "E": return .KeyE
        case "F": return .KeyF
        case "G": return .KeyG
        case "H": return .KeyH
        case "I": return .KeyI
        case "J": return .KeyJ
        case "K": return .KeyK
        case "L": return .KeyL
        case "M": return .KeyM
        case "N": return .KeyN
        case "O": return .KeyO
        case "P": return .KeyP
        case "Q": return .KeyQ
        case "R": return .KeyR
        case "S": return .KeyS
        case "T": return .KeyT
        case "U": return .KeyU
        case "V": return .KeyV
        case "W": return .KeyW
        case "X": return .KeyX
        case "Y": return .KeyY
        case "Z": return .KeyZ
        default: return nil
        }
    }
    
    private static func numberToKeyCode(_ char: Character) -> KeyCode? {
        switch char {
        case "0": return .Key0
        case "1": return .Key1
        case "2": return .Key2
        case "3": return .Key3
        case "4": return .Key4
        case "5": return .Key5
        case "6": return .Key6
        case "7": return .Key7
        case "8": return .Key8
        case "9": return .Key9
        default: return nil
        }
    }
    
}

class ConfigurationManager {
    private static var _shared: ConfigurationManager?
    private var configuration: GKeyConfiguration
    
    static var shared: ConfigurationManager {
        if _shared == nil {
            _shared = ConfigurationManager()
        }
        return _shared!
    }
    
    private init() {
        self.configuration = GKeyConfiguration.defaultConfiguration
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        let customPath = getCustomConfigPath()
        let bundlePath = getBundleConfigPath()
        let homePath = getHomeConfigPath()
        
        G710plus.singleton.logDebug("Configuration search paths:")
        G710plus.singleton.logDebug("1. Custom config: \(customPath ?? "none")")
        G710plus.singleton.logDebug("2. Home config: \(homePath ?? "none")")
        G710plus.singleton.logDebug("3. Bundle config: \(bundlePath ?? "none")")
        
        let configPaths = [customPath, homePath, bundlePath].compactMap { $0 }
        
        for configPath in configPaths {
            G710plus.singleton.logDebug("Checking config file: \(configPath)")
            if loadConfigurationFromFile(path: configPath) {
                G710plus.singleton.logInfo("Loaded configuration from: \(configPath)")
                return
            }
        }
        
        G710plus.singleton.logInfo("Using default G-key configuration")
    }
    
    private func loadConfigurationFromFile(path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else { 
            G710plus.singleton.logDebug("Config file does not exist: \(path)")
            return false 
        }
        
        G710plus.singleton.logDebug("Config file exists: \(path)")
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let config = try JSONDecoder().decode(GKeyConfiguration.self, from: data)
            
            // Validate all key mappings
            let gKeys = ["g1", "g2", "g3", "g4", "g5", "g6"]
            for gKey in gKeys {
                if let mapping = config.getMapping(for: gKey) {
                    let validation = mapping.validate()
                    if !validation.isValid {
                        G710plus.singleton.logInfo("Invalid configuration for \(gKey): \(validation.errorMessage ?? "unknown error")")
                        return false
                    }
                }
            }
            
            self.configuration = config
            G710plus.singleton.logDebug("Successfully parsed and validated config from: \(path)")
            return true
        } catch {
            G710plus.singleton.logInfo("Failed to load config from \(path): \(error)")
            return false
        }
    }
    
    private func getCustomConfigPath() -> String? {
        let args = CommandLine.arguments
        if let configIndex = args.firstIndex(of: "--config"), configIndex + 1 < args.count {
            return args[configIndex + 1]
        }
        return nil
    }
    
    private func getBundleConfigPath() -> String? {
        return Bundle.main.path(forResource: "g710plus-config", ofType: "json")
    }
    
    private func getHomeConfigPath() -> String? {
        guard let homeDir = ProcessInfo.processInfo.environment["HOME"] else { return nil }
        return "\(homeDir)/.g710plus-config.json"
    }
    
    func getKeyMapping(for gKey: String) -> KeyMapping? {
        return configuration.getMapping(for: gKey)
    }
}