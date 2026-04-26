#!/usr/bin/env python3
"""
serial_bridge.py
================
Relays messages between MSP430 (USB serial) and Godot (TCP).

MSP430 -> Godot:  J:x,y,b\n   (joystick state)
Godot -> MSP430:  SONG:X LCD:Y\n  (buzzer and lcd commands)

Usage:
    pip install pyserial
    python serial_bridge.py                      # auto-detect port
    python serial_bridge.py --port COM3          # Windows
    python serial_bridge.py --port /dev/ttyACM0  # Linux
"""

import serial
import serial.tools.list_ports
import socket
import threading
import sys
import argparse


def find_port():
    """Auto-detect the MSP430 serial port."""
    ports = serial.tools.list_ports.comports()

    # common MSP430 USB identifiers
    keywords = ["msp430", "ti", "texas", "ez-fet", "xds110", "acm", "usbmodem"]

    for port in ports:
        desc = f"{port.description} {port.manufacturer or ''} {port.device}".lower()
        if any(kw in desc for kw in keywords):
            print(f"[bridge] Auto-detected: {port.device} — {port.description}")
            return port.device

    # fallback: let user pick
    if ports:
        print("Available serial ports:")
        for i, port in enumerate(ports):
            print(f"  [{i}] {port.device} — {port.description}")
        try:
            choice = int(input("Select port number: "))
            return ports[choice].device
        except (ValueError, IndexError):
            pass

    return None


def main():
    parser = argparse.ArgumentParser(description="MSP430 <-> Godot bridge")
    parser.add_argument("--port", "-p", help="Serial port (auto-detect if omitted)")
    parser.add_argument("--baud", "-b", type=int, default=9600)
    parser.add_argument("--tcp-port", "-t", type=int, default=5555)
    args = parser.parse_args()

    # find serial port
    serial_port = args.port or find_port()
    if not serial_port:
        print("ERROR: No serial port found. Connect MSP430 and retry.")
        sys.exit(1)

    print(f"[bridge] Serial: {serial_port} @ {args.baud} baud")
    print(f"[bridge] TCP:    localhost:{args.tcp_port}")

    # open serial
    try:
        ser = serial.Serial(serial_port, args.baud, timeout=0.001)
        #ser.dtr = False
        #ser.rts = False
    except serial.SerialException as e:
        print(f"ERROR: Cannot open {serial_port}: {e}")
        sys.exit(1)

    # tcp server
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", args.tcp_port))
    server.listen(1)
    server.settimeout(0.1)

    clients = []
    clients_lock = threading.Lock()

    def accept_loop():
        """Accept Godot TCP connections."""
        while True:
            try:
                conn, addr = server.accept()
                conn.setblocking(False)
                with clients_lock:
                    clients.append(conn)
                print(f"[bridge] Godot connected from {addr}")
            except socket.timeout:
                continue
            except OSError:
                break

    def godot_to_msp():
        """Read from Godot TCP clients, forward to MSP430 serial."""
        while True:
            import time
            time.sleep(0.01)
            with clients_lock:
                dead = []
                for client in clients:
                    try:
                        data = client.recv(1024)
                        if data:
                            print(f"  Godot  -> {data.decode('utf-8', errors='replace').strip()}")
                            ser.write(data)
                        elif data == b"":
                            dead.append(client)
                    except BlockingIOError:
                        pass
                    except (ConnectionResetError, BrokenPipeError, OSError):
                        dead.append(client)
                for d in dead:
                    clients.remove(d)
                    d.close()
                    print("[bridge] Godot client disconnected")

    # start background threads
    threading.Thread(target=accept_loop, daemon=True).start()
    threading.Thread(target=godot_to_msp, daemon=True).start()

    print("[bridge] Waiting for Godot to connect...")
    print("[bridge] Ready! Ctrl+C to quit.\n")

    # main loop: serial -> tcp
    try:
        while True:
            line = ser.readline()
            if line:
                decoded = line.decode("utf-8", errors="replace").strip()
                if decoded:
                    print(f"  MSP430 -> {decoded}")

                    # forward to all godot clients
                    msg = (decoded + "\n").encode("utf-8")
                    with clients_lock:
                        dead = []
                        for client in clients:
                            try:
                                client.sendall(msg)
                            except (BrokenPipeError, ConnectionResetError, OSError):
                                dead.append(client)
                        for d in dead:
                            clients.remove(d)
                            d.close()
    except KeyboardInterrupt:
        print("\n[bridge] Shutting down...")
    finally:
        ser.close()
        server.close()


if __name__ == "__main__":
    main()
