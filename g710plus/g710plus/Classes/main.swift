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

let G710PlusVersion = "0.2.1"
let G710PlusBuild = "1003"

// Handle command line arguments
if CommandLine.arguments.count > 1 {
    let argument = CommandLine.arguments[1]
    
    if argument == "--version" || argument == "-v" {
        print("g710plus version \(G710PlusVersion) build \(G710PlusBuild)")
        exit(0)
    } else if argument == "--help" || argument == "-h" {
        print("g710plus version \(G710PlusVersion) build \(G710PlusBuild)")
        print("Usage: g710plus [options]")
        print("Options:")
        print("  --version, -v    Show version information")
        print("  --verbose        Enable verbose logging")
        print("  --help, -h       Show this help message")
        exit(0)
    }
}

let g710plus = G710plus.singleton
let daemon = Thread(target: g710plus, selector: #selector(G710plus.run), object: nil)

daemon.start()
RunLoop.current.run()
