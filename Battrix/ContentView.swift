import SwiftUI
import IOKit
import IOKit.ps

struct BatteryInfo: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct ContentView: View {
    @State var batteryData: [BatteryInfo] = []
    @State private var timer: Timer? = nil
    @State private var showCopiedAlert: Bool = false
    @State private var showDetails: Bool = false    // ← new
    @State private var showBatteryDetails: Bool = false  // Add this new state variable

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Mac Battery Status")
                    .font(.title)
                Spacer()
                Button(action: {
                    copyBatteryDataToClipboard()
                }) {
                    Image(systemName: "doc.on.doc")
                        .font(.title2)
                }
                .padding(.trailing, 8)
                .help("Copy all battery data")
                
                Button(action: {
                    batteryData = getBatteryStats()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                .help("Refresh battery data")
            }
            .padding(.bottom)

            // 1) split data
            let adapterInfo = batteryData.filter {
                $0.label.hasPrefix("Adapter") || $0.label == "AC Adapter Connected"
            }
            let otherInfo = batteryData.filter {
                !($0.label.hasPrefix("Adapter")) && 
                $0.label != "AC Adapter Connected" && 
                $0.label != "Battery ID" &&
                $0.label != "Serial Number"
            }

            // 2) show all the "other" stats
            ForEach(otherInfo) { info in
                HStack {
                    Text(info.label + ":").bold()
                    Spacer()
                    Text(info.value)
                    
                    // Add info button specifically for Battery Health
                    if info.label == "Battery Health" {
                        Button {
                            showBatteryDetails.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .buttonStyle(PlainButtonStyle())
                        .popover(isPresented: $showBatteryDetails, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                if let batteryID = batteryData.first(where: { $0.label == "Battery ID" }) {
                                    HStack {
                                        Text("Battery ID:").bold()
                                        Spacer()
                                        Text(batteryID.value)
                                    }
                                }
                                
                                if let serial = batteryData.first(where: { $0.label == "Serial Number" }) {
                                    HStack {
                                        Text("Serial Number:").bold()
                                        Spacer()
                                        Text(serial.value)
                                    }
                                }
                                
                                // Also display cycle count info in the details
                                if let cycleCount = batteryData.first(where: { $0.label == "Cycle Count" }) {
                                    HStack {
                                        Text("Cycle Count:").bold()
                                        Spacer()
                                        Text(cycleCount.value)
                                    }
                                }
                                
                                // Add design capacity info
                                if let designCapacity = batteryData.first(where: { $0.label == "Design Capacity" }) {
                                    HStack {
                                        Text("Design Capacity:").bold()
                                        Spacer()
                                        Text(designCapacity.value)
                                    }
                                }
                                
                                // Display battery lifetime data if available
                                // if let opTime = batteryData.first(where: { $0.label == "Total Operating Time" }) {
                                //     HStack {
                                //         Text("Total Usage:").bold()
                                //         Spacer()
                                //         Text(opTime.value)
                                //     }
                                // }
                            }
                            .padding()
                            .frame(width: 300)
                        }
                    }
                }
            }

            // 3) at the very bottom, show only Adapter Wattage + info button
            if let adapter = batteryData.first(where: { $0.label == "Adapter Wattage" }) {
                HStack {
                    Text(adapter.label + ":").bold()
                    Spacer()
                    Text(adapter.value)

                    Button {
                        showDetails.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(PlainButtonStyle())
                    .popover(isPresented: $showDetails, arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(adapterInfo) { info in
                                HStack {
                                    Text(info.label + ":").bold()
                                    Spacer()
                                    Text(info.value)
                                }
                            }
                        }
                        .padding()
                        .frame(width: 300)
                    }
                }
            }

        }
        .padding()
        .onAppear { batteryData = getBatteryStats() }
        .onDisappear {
            timer?.invalidate()
        }
        .frame(width: 400)
        .overlay(
            showCopiedAlert ? 
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.7))
                        .frame(width: 120, height: 40)
                    
                    Text("Copied!")
                        .foregroundColor(.white)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopiedAlert = false
                        }
                    }
                }
                : nil
        )
    }
    
    private func copyBatteryDataToClipboard() {
        let formattedText = batteryData.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(formattedText, forType: .string)
        
        withAnimation {
            showCopiedAlert = true
        }
    }
}

// Remove the entire extractManufactureDate function
private func daysSinceManufacture(_ date: Date) -> Int {
    let calendar = Calendar.current
    let now = Date()
    let components = calendar.dateComponents([.day], from: date, to: now)
    return components.day ?? 0
}

private func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}

func getBatteryStats() -> [BatteryInfo] {
    var stats: [BatteryInfo] = []
    
    let batteryService = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"))
    if batteryService != 0 {
        var properties: Unmanaged<CFMutableDictionary>?
        
        if IORegistryEntryCreateCFProperties(batteryService, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
           let propDict = properties?.takeRetainedValue() as? [String: Any] {
            
            // Print ALL battery properties to console for debugging
            print("=== ALL BATTERY PROPERTIES ===")
            let sortedKeys = propDict.keys.sorted()
            for key in sortedKeys {
                let value = propDict[key] ?? "nil"
                print("\(key): \(value)")
            }
            print("============================")
            
            // Current capacity (in mAh)
            if let absoluteCapacity = propDict["AppleRawCurrentCapacity"] as? Int {
                stats.append(BatteryInfo(label: "Current Capacity", value: "\(absoluteCapacity) mAh"))
            } else if let absoluteCapacity = propDict["AbsoluteCapacity"] as? Int {
                stats.append(BatteryInfo(label: "Current Capacity", value: "\(absoluteCapacity) mAh"))
            } else if let current = propDict["CurrentCapacity"] as? Int {
                stats.append(BatteryInfo(label: "Current Capacity", value: "\(current) units"))
            }
            
            // Max capacity (in mAh)
            if let rawMaxCapacity = propDict["AppleRawMaxCapacity"] as? Int {
                stats.append(BatteryInfo(label: "Max Capacity", value: "\(rawMaxCapacity) mAh"))
            } else if let maxCapacity = propDict["MaxCapacity"] as? Int {
                stats.append(BatteryInfo(label: "Max Capacity", value: "\(maxCapacity) units"))
            }
            
            // Design capacity
            if let designCapacity = propDict["DesignCapacity"] as? Int {
                stats.append(BatteryInfo(label: "Design Capacity", value: "\(designCapacity) mAh"))
            }
            
            // Cycle count
            if let cycleCount = propDict["CycleCount"] as? Int {
                stats.append(BatteryInfo(label: "Cycle Count", value: "\(cycleCount)"))
            }
            
            // Get the life time data
            if let batteryData = propDict["BatteryData"] as? [String: Any],
               let lifetimeData = batteryData["LifetimeData"] as? [String: Any] {
                
                // Maximum charge current - already commented out
                // if let maxChargeCurrent = lifetimeData["MaximumChargeCurrent"] as? Int {
                //     stats.append(BatteryInfo(label: "Max Charge Current", value: "\(maxChargeCurrent) mA"))
                // }
                
                // Maximum discharge current
                if let maxDischargeCurrent = lifetimeData["MaximumDischargeCurrent"] as? String {
                    stats.append(BatteryInfo(label: "Max Discharge Current", value: "\(maxDischargeCurrent) mA"))
                }
            }
            
            // Temperature
            if let temperature = propDict["Temperature"] as? Int {
                let tempCelsius = Double(temperature) / 100.0
                let tempFahrenheit = tempCelsius * 9/5 + 32
                stats.append(BatteryInfo(label: "Temperature", value: String(format: "%.1f°C / %.1f°F", tempCelsius, tempFahrenheit)))
            }
            
            // Voltage
            if let voltage = propDict["Voltage"] as? Int {
                let volts = Double(voltage) / 1000.0
                stats.append(BatteryInfo(label: "Voltage", value: String(format: "%.2f V", volts)))
            }
            
            // Amperage - with sign indicating charging (+) or discharging (-)
            if let instantAmperage = propDict["InstantAmperage"] as? Int {
                let sign = instantAmperage > 0 ? "+" : (instantAmperage < 0 ? "-" : "")
                stats.append(BatteryInfo(label: "Amperage", value: "\(sign)\(abs(instantAmperage)) mA"))
            } else if let amperage = propDict["Amperage"] as? Int {
                let sign = amperage > 0 ? "+" : (amperage < 0 ? "-" : "")
                stats.append(BatteryInfo(label: "Amperage", value: "\(sign)\(abs(amperage)) mA"))
            }
            
            // Power calculation
            if let voltage = propDict["Voltage"] as? Int {
                let amperage = propDict["InstantAmperage"] as? Int ?? propDict["Amperage"] as? Int ?? 0
                let powerInWatts = Double(voltage) * Double(amperage) / 1000000.0
                if amperage != 0 {
                    let sign = powerInWatts > 0 ? "+" : ""
                    stats.append(BatteryInfo(label: "Power", value: String(format: "%@%.2f W", sign, abs(powerInWatts))))
                } else {
                    stats.append(BatteryInfo(label: "Power", value: "0.00 W"))
                }
            }
            
            // Charging status
            if let isCharging = propDict["IsCharging"] as? Bool {
                stats.append(BatteryInfo(label: "Charging", value: isCharging ? "Yes" : "No"))
            }
            
            if let fullyCharged = propDict["FullyCharged"] as? Bool {
                stats.append(BatteryInfo(label: "Fully Charged", value: fullyCharged ? "Yes" : "No"))
            }
            
            // Battery charge percentage based on raw capacity values
            if let rawCurrentCapacity = propDict["AppleRawCurrentCapacity"] as? Int,
            let rawMaxCapacity = propDict["AppleRawMaxCapacity"] as? Int,
            rawMaxCapacity > 0 {
                let chargePercent = Double(rawCurrentCapacity) / Double(rawMaxCapacity) * 100
                stats.append(BatteryInfo(label: "Charge %", value: String(format: "%.1f%%", chargePercent)))
            }
            
            // Battery health - FIXED calculation using raw values
            if let rawMaxCapacity = propDict["AppleRawMaxCapacity"] as? Int, 
               let designCapacity = propDict["DesignCapacity"] as? Int, 
               designCapacity > 0 {
                let health = Double(rawMaxCapacity) / Double(designCapacity) * 100
                stats.append(BatteryInfo(label: "Battery Health", value: String(format: "%.1f%%", health)))
            }
            
            // Add battery temperature
            if let temperature = propDict["Temperature"] as? Int {
                // Temperature is in Celsius * 100
                let tempCelsius = Double(temperature) / 100.0
                let tempFahrenheit = tempCelsius * 9/5 + 32
                stats.append(BatteryInfo(label: "Temperature", value: String(format: "%.1f°C / %.1f°F", tempCelsius, tempFahrenheit)))
            }

            // Better manufacturing data parsing - searching for ASCII encoded info
            // Store this data but don't add to the main stats list
            var batteryIdValue = ""
            if let manufacturerData = propDict["ManufacturerData"] as? Data {
                // Print raw data for debugging
                let hexString = manufacturerData.map { String(format: "%02x", $0) }.joined()
                print("Raw manufacturer data hex: \(hexString)")
                
                // The data appears to contain length-prefixed ASCII strings
                var position = 0
                var dataStrings: [String] = []
                
                while position < manufacturerData.count {
                    if position < manufacturerData.count - 1 && manufacturerData[position] > 0 && manufacturerData[position] < 20 {
                        // Possible length byte
                        let length = Int(manufacturerData[position])
                        if position + length < manufacturerData.count {
                            let range = (position+1)..<(position+1+length)
                            if let str = String(data: manufacturerData.subdata(in: range), encoding: .ascii),
                               !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                dataStrings.append(str)
                            }
                            position += 1 + length
                        } else {
                            position += 1
                        }
                    } else {
                        position += 1
                    }
                }
                
                print("Extracted strings from manufacturer data: \(dataStrings)")
                
                // Try to identify a date pattern in these strings
                if !dataStrings.isEmpty {
                    let filteredStrings = dataStrings.filter { !$0.isEmpty }
                    if !filteredStrings.isEmpty {
                        batteryIdValue = filteredStrings.joined(separator: "-")
                        stats.append(BatteryInfo(label: "Battery ID", value: batteryIdValue))
                        
                        // Also print individual strings for debugging date extraction
                        for (index, string) in filteredStrings.enumerated() {
                            print("String \(index): \(string)")
                        }
                    }
                }
            }
            
            // Add battery serial number (but don't display in the main list)
            if let serial = propDict["Serial"] as? String, !serial.isEmpty {
                stats.append(BatteryInfo(label: "Serial Number", value: serial))
                print("Battery Serial Number: \(serial)")
            }
            
            // Add power adapter information if available - FIXED
            if let adapterDetails = propDict["AdapterDetails"] as? [String: Any] {
                print("Adapter details: \(adapterDetails)")
                
                // Extract watts
                if let watts = adapterDetails["Watts"] as? Int {
                    stats.append(BatteryInfo(label: "Adapter Wattage", value: "\(watts)W"))
                }
                
                // Extract adapter name
                if let name = adapterDetails["Name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    stats.append(BatteryInfo(label: "Adapter Name", value: name.trimmingCharacters(in: .whitespacesAndNewlines)))
                }
                
                // Extract adapter voltage
                if let voltage = adapterDetails["AdapterVoltage"] as? Int {
                    let volts = Double(voltage) / 1000.0
                    stats.append(BatteryInfo(label: "Adapter Voltage", value: String(format: "%.1f V", volts)))
                }
                
                // Extract adapter current
                if let current = adapterDetails["Current"] as? Int {
                    let amps = Double(current) / 1000.0
                    stats.append(BatteryInfo(label: "Adapter Current", value: String(format: "%.2f A", amps)))
                }
                
                // Extract serial string
                if let serialString = adapterDetails["SerialString"] as? String, !serialString.isEmpty {
                    stats.append(BatteryInfo(label: "Adapter Serial", value: serialString))
                }
                
                // Extract manufacturer
                if let manufacturer = adapterDetails["Manufacturer"] as? String, !manufacturer.isEmpty {
                    stats.append(BatteryInfo(label: "Adapter Manufacturer", value: manufacturer))
                }
            }
            
            // Check for external connection status
            if let externalConnected = propDict["ExternalConnected"] as? Bool {
                stats.append(BatteryInfo(label: "AC Adapter Connected", value: externalConnected ? "Yes" : "No"))
            }
        }
        
        IOObjectRelease(batteryService)
    }
    
    return stats
}