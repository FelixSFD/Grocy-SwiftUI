//
//  MDQuantityUnitFormView.swift
//  Grocy-SwiftUI
//
//  Created by Georg Meissner on 17.11.20.
//

import SwiftUI

struct MDQuantityUnitFormView: View {
    @StateObject var grocyVM: GrocyViewModel = .shared
    
    @Environment(\.dismiss) var dismiss
    
    @State private var firstAppear: Bool = true
    @State private var isProcessing: Bool = false
    
    @State private var name: String = ""
    @State private var namePlural: String = ""
    @State private var mdQuantityUnitDescription: String = ""
    
    var isNewQuantityUnit: Bool
    var quantityUnit: MDQuantityUnit?
    
    @Binding var showAddQuantityUnit: Bool
    @Binding var toastType: MDToastType?
    
    @State private var showAddQuantityUnitConversion: Bool = false
    
    @State private var isNameCorrect: Bool = false
    private func checkNameCorrect() -> Bool {
        let foundQuantityUnit = grocyVM.mdQuantityUnits.first(where: {$0.name == name})
        return isNewQuantityUnit ? !(name.isEmpty || foundQuantityUnit != nil) : !(name.isEmpty || (foundQuantityUnit != nil && foundQuantityUnit!.id != quantityUnit!.id))
    }
    
    private func resetForm() {
        self.name = quantityUnit?.name ?? ""
        self.namePlural = quantityUnit?.namePlural ?? ""
        self.mdQuantityUnitDescription = quantityUnit?.mdQuantityUnitDescription ?? ""
        isNameCorrect = checkNameCorrect()
    }
    
    private let dataToUpdate: [ObjectEntities] = [.quantity_units, .quantity_unit_conversions]
    private func updateData() {
        grocyVM.requestData(objects: dataToUpdate)
    }
    
    private var quConversions: MDQuantityUnitConversions? {
        if !isNewQuantityUnit, let quantityUnitID = quantityUnit?.id {
            return grocyVM.mdQuantityUnitConversions.filter({ $0.fromQuID == quantityUnitID })
        } else {
            return nil
        }
    }
    
    private func finishForm() {
#if os(iOS)
        self.dismiss()
#elseif os(macOS)
        if isNewQuantityUnit {
            showAddQuantityUnit = false
        }
#endif
    }
    
    private func saveQuantityUnit() {
        let id = isNewQuantityUnit ? grocyVM.findNextID(.quantity_units) : quantityUnit!.id
        let timeStamp = isNewQuantityUnit ? Date().iso8601withFractionalSeconds : quantityUnit!.rowCreatedTimestamp
        let quantityUnitPOST = MDQuantityUnit(id: id, name: name, namePlural: namePlural, mdQuantityUnitDescription: mdQuantityUnitDescription, rowCreatedTimestamp: timeStamp)
        isProcessing = true
        if isNewQuantityUnit {
            grocyVM.postMDObject(object: .quantity_units, content: quantityUnitPOST, completion: { result in
                switch result {
                case let .success(message):
                    grocyVM.postLog("Quantity unit add successful. \(message)", type: .info)
                    toastType = .successAdd
                    resetForm()
                    updateData()
                    finishForm()
                case let .failure(error):
                    grocyVM.postLog("Quantity unit add failed. \(error)", type: .error)
                    toastType = .failAdd
                }
                isProcessing = false
            })
        } else {
            grocyVM.putMDObjectWithID(object: .quantity_units, id: id, content: quantityUnitPOST, completion: { result in
                switch result {
                case let .success(message):
                    grocyVM.postLog("Quantity unit edit successful. \(message)", type: .info)
                    toastType = .successEdit
                    updateData()
                    finishForm()
                case let .failure(error):
                    grocyVM.postLog("Quantity unit edit failed. \(error)", type: .error)
                    toastType = .failEdit
                }
                isProcessing = false
            })
        }
    }
    
    var body: some View {
        content
            .navigationTitle(isNewQuantityUnit ? LocalizedStringKey("str.md.quantityUnit.new") : LocalizedStringKey("str.md.quantityUnit.edit"))
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    if isNewQuantityUnit {
                        Button(LocalizedStringKey("str.cancel")) {
                            finishForm()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveQuantityUnit, label: {
                        Label(LocalizedStringKey("str.md.quantityUnit.save"), systemImage: MySymbols.save)
                            .labelStyle(.titleAndIcon)
                    })
                        .disabled(!isNameCorrect || isProcessing)
                        .keyboardShortcut(.defaultAction)
                }
            })
    }
    
    var content: some View {
        Form {
#if os(macOS)
            Text(isNewQuantityUnit ? LocalizedStringKey("str.md.quantityUnit.new") : LocalizedStringKey("str.md.quantityUnit.edit"))
                .font(.title)
                .bold()
                .padding(.bottom, 20.0)
#endif
            Section(header: Text(LocalizedStringKey("str.md.quantityUnit.info"))){
                MyTextField(textToEdit: $name, description: "str.md.quantityUnit.name", isCorrect: $isNameCorrect, leadingIcon: "tag", emptyMessage: "str.md.quantityUnit.name.required", errorMessage: "str.md.quantityUnit.name.exists")
                    .onChange(of: name, perform: { value in
                        isNameCorrect = checkNameCorrect()
                    })
                MyTextField(textToEdit: $namePlural, description: "str.md.quantityUnit.namePlural", isCorrect: Binding.constant(true), leadingIcon: "tag")
                MyTextField(textToEdit: $mdQuantityUnitDescription, description: "str.md.description", isCorrect: Binding.constant(true), leadingIcon: MySymbols.description)
            }
            if !isNewQuantityUnit, let quantityUnit = quantityUnit {
                Section(header: VStack(alignment: .leading) {
                    HStack(alignment: .top) {
                        Text(LocalizedStringKey("str.md.quantityUnit.conversions"))
                        Spacer()
                        Button(action: {
                            showAddQuantityUnitConversion.toggle()
                        }, label: {
                            Image(systemName: MySymbols.new)
                                .font(.body)
                        })
                    }
                    Text(LocalizedStringKey("str.md.quantityUnit.conversions.hint \("1 \(quantityUnit.name)")"))
                        .italic()
                })
                {
                    List {
                    ForEach(quConversions ?? [], id:\.id) { quConversion in
                        NavigationLink(destination: {
                            MDQuantityUnitConversionFormView(isNewQuantityUnitConversion: false, quantityUnit: quantityUnit, quantityUnitConversion: quConversion, showAddQuantityUnitConversion: $showAddQuantityUnitConversion, toastType: $toastType)
                        }, label: {
                            Text("\(quConversion.factor.formattedAmount) \(grocyVM.mdQuantityUnits.first(where: { $0.id == quConversion.toQuID })?.name ?? "\(quConversion.id)")")
                        })
                    }
                    }
                }
                .sheet(isPresented: $showAddQuantityUnitConversion, content: {
                    NavigationView {
                        MDQuantityUnitConversionFormView(isNewQuantityUnitConversion: true, quantityUnit: quantityUnit, showAddQuantityUnitConversion: $showAddQuantityUnitConversion, toastType: $toastType)
                    }
                })
            }
        }
        .refreshable {
            grocyVM.requestData(objects: [.quantity_unit_conversions])
        }
        .onAppear(perform: {
            if firstAppear {
                grocyVM.requestData(objects: dataToUpdate, ignoreCached: false)
                resetForm()
                firstAppear = false
            }
        })
    }
}

struct MDQuantityUnitFormView_Previews: PreviewProvider {
    static var previews: some View {
#if os(macOS)
        Group {
            MDQuantityUnitFormView(isNewQuantityUnit: true, showAddQuantityUnit: Binding.constant(true), toastType: Binding.constant(.successAdd))
            MDQuantityUnitFormView(isNewQuantityUnit: false, quantityUnit: MDQuantityUnit(id: 0, name: "Quantity unit", namePlural: "QU Plural", mdQuantityUnitDescription: "Description", rowCreatedTimestamp: ""), showAddQuantityUnit: Binding.constant(false), toastType: Binding.constant(.successAdd))
        }
#else
        Group {
            NavigationView {
                MDQuantityUnitFormView(isNewQuantityUnit: true, showAddQuantityUnit: Binding.constant(true), toastType: Binding.constant(.successAdd))
            }
            NavigationView {
                MDQuantityUnitFormView(isNewQuantityUnit: false, quantityUnit: MDQuantityUnit(id: 0, name: "Quantity unit", namePlural: "QU Plural", mdQuantityUnitDescription: "Description", rowCreatedTimestamp: ""), showAddQuantityUnit: Binding.constant(false), toastType: Binding.constant(.successAdd))
            }
        }
#endif
    }
}
