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
import AppKit

// Disable stdout buffering to ensure logs are written immediately
setbuf(stdout, nil)

let timestamp = DateFormatter()
timestamp.dateFormat = "yyyy-MM-dd HH:mm:ss"
let buildNumber = "1001" // Increment manually: 1001 = IOHIDDeviceOpen fix
print("[\(timestamp.string(from: Date()))] G710+ Utility Starting...")
print("[\(timestamp.string(from: Date()))] Build: \(buildNumber)")
print("[\(timestamp.string(from: Date()))] Command line arguments: \(CommandLine.arguments)")
print("[\(timestamp.string(from: Date()))] Process ID: \(getpid())")
fflush(stdout)

let g710plus = G710plus.singleton
let daemon = Thread(target: g710plus, selector: #selector(G710plus.run), object: nil)

print("[\(timestamp.string(from: Date()))] Starting daemon thread...")
fflush(stdout)
daemon.start()

print("[\(timestamp.string(from: Date()))] Starting main run loop...")
fflush(stdout)
RunLoop.current.run()
