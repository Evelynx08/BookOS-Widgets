#!/usr/bin/env python3
import subprocess
import json

def get_devices():
    devices = []
    try:
        # Get all devices
        output = subprocess.check_output(['upower', '-e'], text=True)
        device_paths = [p.strip() for p in output.split('\n') if p.strip()]

        for path in device_paths:
            if 'DisplayDevice' in path or 'line_power' in path: 
                continue # Skip the display device and AC adapters
            
            try:
                info = subprocess.check_output(['upower', '-i', path], text=True)
                device: dict = {}
                is_battery = False
                
                # Default icons based on path naming
                icon = "battery"
                if "headset" in path.lower() or "buds" in path.lower() or "airpods" in path.lower():
                    icon = "audio-headphones-bluetooth"
                elif "mouse" in path.lower():
                    icon = "input-mouse"
                elif "keyboard" in path.lower():
                    icon = "input-keyboard"
                elif "phone" in path.lower() or "iphone" in path.lower():
                    icon = "smartphone"
                
                device["icon"] = icon
                device["name"] = "Unknown Device"
                device["percentage"] = 0
                device["isCharging"] = False
                device["isMainBattery"] = ("BAT" in path)

                for line in info.split('\n'):
                    line = line.strip()
                    if line.startswith('model:'):
                        device["name"] = line.split(':', 1)[1].strip()
                    elif line.startswith('percentage:'):
                        pct_str = line.split(':', 1)[1].strip().replace('%', '')
                        try:
                            device["percentage"] = int(float(pct_str))
                        except ValueError:
                            pass
                    elif line.startswith('state:'):
                        state = line.split(':', 1)[1].strip()
                        device["isCharging"] = (state == "charging" or state == "fully-charged")
                    elif line.startswith('native-path:'):
                        # Use native path as fallback name if model is empty/generic
                        npath = line.split(':', 1)[1].strip()
                        if device["name"] == "Unknown Device" or device["name"] == "":
                            device["name"] = npath
                    elif line.startswith('power supply:'):
                        val = line.split(':', 1)[1].strip()
                        if val == "yes":
                            is_battery = True

                if (device["percentage"] > 0) and not ("mac" in device["name"].lower() and "address" in device["name"].lower()):
                    if device["name"] == "Unknown Device":
                       device["name"] = "Batería Interna" if device["isMainBattery"] else "Accesorio"
                    devices.append(device)

            except subprocess.CalledProcessError:
                continue
                
    except FileNotFoundError:
        pass # upower not installed or accessible

    # Sort main battery to top
    devices.sort(key=lambda x: (not x.get("isMainBattery", False), x.get("name", "")))
    
    print(json.dumps(devices))

if __name__ == "__main__":
    get_devices()
