//
//  ContentView.swift
//  VehicleReaderDemo
//
//  Minimal UI demonstrating SerbianVehicleKit. Requires the
//  com.apple.security.smartcard entitlement and a CCID reader.
//

import SwiftUI
import SerbianVehicleKit

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published var document: VehicleDocument?
    @Published var status = "Ready. Connect the reader and insert the vehicle card."
    @Published var isLoading = false
    @Published var logs: [String] = []

    func read() {
        isLoading = true
        status = "Reading…"
        document = nil
        logs = []
        Task {
            do {
                let reader = try await VehicleCardReader()
                reader.onLog = { [weak self] line in
                    Task { @MainActor in self?.logs.append(line) }
                }
                self.document = try await reader.readAll()
                self.status = "Read successfully."
            } catch {
                self.status = "Error: \(error)"
                self.logs.append("‼︎ \(error)")
            }
            self.isLoading = false
        }
    }
}

struct ContentView: View {
    @StateObject private var model = ReaderViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: model.read) {
                        Label(model.isLoading ? "Reading…" : "Read card", systemImage: "car")
                    }
                    .disabled(model.isLoading)
                    Text(model.status).font(.footnote).foregroundStyle(.secondary)
                }

                if let doc = model.document {
                    Section("Vehicle") {
                        row("Registration", doc.registrationNumberOfVehicle)
                        row("VIN", doc.vehicleIdNumber)
                        row("Make", doc.vehicleMake)
                        row("Description", doc.commercialDescription)
                        row("Category", doc.vehicleCategory)
                        row("Year", doc.yearOfProduction)
                        row("Colour", doc.colourOfVehicle)
                    }
                    Section("Technical") {
                        row("Engine capacity", doc.engineCapacity)
                        row("Max net power", doc.maximumNetPower)
                        row("Fuel", doc.typeOfFuel)
                        row("Mass", doc.vehicleMass)
                        row("Seats", doc.numberOfSeats)
                    }
                    Section("Registration dates") {
                        row("First registration", doc.dateOfFirstRegistration)
                        row("Issued", doc.issuingDate)
                        row("Expires", doc.expiryDate)
                    }
                    Section("Owner") {
                        row("Name", doc.ownerName)
                        row("Surname / business", doc.ownersSurnameOrBusinessName)
                        row("Address", doc.ownerAddress)
                    }
                    if !doc.usersName.isEmpty || !doc.usersSurnameOrBusinessName.isEmpty {
                        Section("User") {
                            row("Name", doc.usersName)
                            row("Surname / business", doc.usersSurnameOrBusinessName)
                            row("Address", doc.usersAddress)
                        }
                    }
                }

                if !model.logs.isEmpty {
                    Section("APDU log") {
                        ScrollView {
                            Text(model.logs.joined(separator: "\n"))
                                .font(.system(size: 11, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 220)
                    }
                }
            }
            .navigationTitle("SerbianVehicleKit")
        }
    }

    @ViewBuilder
    private func row(_ label: String, _ value: String) -> some View {
        if !value.trimmingCharacters(in: .whitespaces).isEmpty {
            LabeledContent(label, value: value)
        }
    }
}

#Preview { ContentView() }
