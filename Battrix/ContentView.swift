import SwiftUI
import IOKit
import IOKit.ps
import AppKit // Replace UIKit with AppKit for macOS

struct BatteryInfo: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct ContentView: View {
    @State var batteryData: [BatteryInfo] = []
    @State private var timer: Timer? = nil
    @State private var showCopiedAlert: Bool = false
    @State private var showDetails: Bool = false
    @State private var showBatteryDetails: Bool = false
    
    // Add new state for animation
    @State private var isRefreshing: Bool = false
    
    // Extract battery charge percentage for battery indicator
    private var batteryPercentage: Double {
        if let info = batteryData.first(where: { $0.label == "Charge %" }) {
            let percentText = info.value.replacingOccurrences(of: "%", with: "")
            return Double(percentText) ?? 0
        }
        return 0
    }
    
    // Get battery color based on percentage and charging status
    private var batteryColor: Color {
        let isCharging = batteryData.first(where: { $0.label == "Charging" })?.value == "Yes"
        
        if isCharging {
            return .green
        } else if batteryPercentage <= 20 {
            return .red
        } else if batteryPercentage <= 50 {
            return .orange
        } else {
            return .blue
        }
    }
    
    var body: some View {
        ZStack {
            // Replace gradient with solid background color
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 10) {
                // Header with app title and buttons
                HStack {
                    Text("Mac Battery Status")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        copyBatteryDataToClipboard()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(8)
                    .background(Color(NSColor.controlColor).opacity(0.5))
                    .cornerRadius(8)
                    .padding(.trailing, 8)
                    .help("Copy all battery data")
                    
                    Button(action: {
                        withAnimation {
                            isRefreshing = true
                            batteryData = getBatteryStats()
                            
                            // Reset the animation after a delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                isRefreshing = false
                            }
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .rotationEffect(Angle(degrees: isRefreshing ? 360 : 0))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(8)
                    .background(Color(NSColor.controlColor).opacity(0.5))
                    .cornerRadius(8)
                    .help("Refresh battery data")
                }
                .padding(.bottom)
                
                // Battery level indicator
                if batteryPercentage > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Battery Level")
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(Int(batteryPercentage))%")
                                .fontWeight(.semibold)
                        }
                        
                        // Fix 1: Replace systemGray4 with NSColor reference
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(NSColor.gridColor)) // Changed from .systemGray4
                                    .frame(height: 12)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(batteryColor)
                                    .frame(width: max(0, min(geometry.size.width * batteryPercentage / 100, geometry.size.width)), height: 12)
                                    .animation(.easeInOut, value: batteryPercentage)
                            }
                        }
                        .frame(height: 12)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                }
                
                // Divider with section title
                HStack {
                    Text("Battery Information")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color(NSColor.separatorColor)) // Replace systemGray3 with NSColor equivalent
                        .frame(height: 1)
                }
                .padding(.top, 4)
                
                // 1) split data - keep your existing code
                let adapterInfo = batteryData.filter {
                    $0.label.hasPrefix("Adapter") || $0.label == "AC Adapter Connected"
                }
                let otherInfo = batteryData.filter {
                    !($0.label.hasPrefix("Adapter")) &&
                    $0.label != "AC Adapter Connected" &&
                    $0.label != "Battery ID" &&
                    $0.label != "Serial Number"
                }
                
                // 2) Battery information cards
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(otherInfo) { info in
                            HStack {
                                // Add relevant icons based on label
                                Image(systemName: iconFor(label: info.label))
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                Text(info.label + ":")
                                    .bold()
                                Spacer()
                                Text(info.value)
                                    .foregroundColor(.primary)
                                
                                // Add info button specifically for Battery Health
                                if info.label == "Battery Health" {
                                    Button {
                                        showBatteryDetails.toggle()
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .popover(isPresented: $showBatteryDetails, arrowEdge: .top) {
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Battery Details")
                                                .font(.headline)
                                                .padding(.bottom, 4)
                                            
                                            if let batteryID = batteryData.first(where: { $0.label == "Battery ID" }) {
                                                HStack {
                                                    Image(systemName: "number")
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 24)
                                                    Text("Battery ID:").bold()
                                                    Spacer()
                                                    Text(batteryID.value)
                                                }
                                            }
                                            
                                            if let serial = batteryData.first(where: { $0.label == "Serial Number" }) {
                                                HStack {
                                                    Image(systemName: "barcode")
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 24)
                                                    Text("Serial Number:").bold()
                                                    Spacer()
                                                    Text(serial.value)
                                                }
                                            }
                                            
                                            if let cycleCount = batteryData.first(where: { $0.label == "Cycle Count" }) {
                                                HStack {
                                                    Image(systemName: "repeat")
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 24)
                                                    Text("Cycle Count:").bold()
                                                    Spacer()
                                                    Text(cycleCount.value)
                                                }
                                            }
                                            
                                            if let designCapacity = batteryData.first(where: { $0.label == "Design Capacity" }) {
                                                HStack {
                                                    Image(systemName: "cube")
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 24)
                                                    Text("Design Capacity:").bold()
                                                    Spacer()
                                                    Text(designCapacity.value)
                                                }
                                            }
                                        }
                                        .padding()
                                        .frame(width: 300)
                                        .background(Color(NSColor.textBackgroundColor))
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                        }
                    }
                }
                .frame(maxHeight: 300)
                
                // Divider with section title for adapter info
                HStack {
                    Text("Power Adapter")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Rectangle()
                        .fill(Color(NSColor.separatorColor)) // Replace systemGray3 with NSColor equivalent
                        .frame(height: 1)
                }
                .padding(.top, 8)
                
                // 3) Adapter information with improved styling
                if let adapter = batteryData.first(where: { $0.label == "Adapter Wattage" }) {
                    HStack {
                        Image(systemName: "powerplug")
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        
                        Text(adapter.label + ":")
                            .bold()
                        Spacer()
                        Text(adapter.value)
                            .foregroundColor(.primary)
                        
                        Button {
                            showDetails.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .popover(isPresented: $showDetails, arrowEdge: .top) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Adapter Details")
                                    .font(.headline)
                                    .padding(.bottom, 4)
                                
                                ForEach(adapterInfo) { info in
                                    HStack {
                                        Image(systemName: iconFor(label: info.label))
                                            .foregroundColor(.secondary)
                                            .frame(width: 24)
                                        Text(info.label + ":")
                                            .bold()
                                        Spacer()
                                        Text(info.value)
                                    }
                                }
                            }
                            .padding()
                            .frame(width: 300)
                            .background(Color(NSColor.textBackgroundColor))
                        }
                    }
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                }
            }
            .padding()
            .onAppear { batteryData = getBatteryStats() }
            .onDisappear {
                timer?.invalidate()
            }
            .frame(width: 400)
            
            // Copied alert with improved styling
            if showCopiedAlert {
                VStack {
                    Text("Copied!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.7))
                        )
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation {
                            showCopiedAlert = false
                        }
                    }
                }
            }
        }
    }
    
    // Helper function to get appropriate icon for each label
    private func iconFor(label: String) -> String {
        switch label {
        case "Current Capacity", "Max Capacity", "Design Capacity":
            return "battery.100"
        case "Cycle Count":
            return "repeat"
        case "Temperature":
            return "thermometer"
        case "Voltage":
            return "bolt.fill"
        case "Amperage":
            return "bolt.circle"
        case "Power":
            return "power"
        case "Charging", "Fully Charged":
            return "battery.100.bolt"
        case "Charge %":
            return "percent"
        case "Battery Health":
            return "heart"
        case "Max Discharge Current":
            return "arrow.down.circle"
        case "Adapter Wattage":
            return "powerplug"
        case "Adapter Name":
            return "tag"
        case "Adapter Voltage":
            return "bolt"
        case "Adapter Current":
            return "bolt.circle"
        case "Adapter Serial":
            return "barcode"
        case "Adapter Manufacturer":
            return "building.2"
        case "AC Adapter Connected":
            return "link"
        default:
            return "info.circle"
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
    
    // Helper function to copy battery data to clipboard
    private func copyBatteryDataToClipboard() {
        let dataString = batteryData.map { "\($0.label): \($0.value)" }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(dataString, forType: .string)
        
        withAnimation {
            showCopiedAlert = true
        }
    }
}