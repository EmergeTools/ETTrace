//
//  ConnectivityHelper.swift
//  ETTrace
//
//  Created by Noah Martin on 2/27/25.
//

import Foundation

func isPortInUse(port: Int) -> Bool {
    let sock = socket(AF_INET, SOCK_STREAM, 0)
    if sock == -1 {
        print("Failed to create socket")
        return false
    }

    var addr = sockaddr_in()
    addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size);
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = in_port_t(port).bigEndian
    addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

    let result = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }

    close(sock)

    return result == 0
}
