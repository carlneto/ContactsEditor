import Contacts
import Combine

// MARK: - Models

enum PhoneAction: String, CaseIterable {
   case skip = "Ignorar"
   case addPrefix = "Adicionar +351"
   case removeSpaces = "Apagar espaços"
   case delete = "Eliminar"
}

struct PhoneNumberItem: Identifiable, Hashable {
   let id = UUID()
   let number: String
   let label: String
   var action: PhoneAction = .skip
   var normalizedNumber: String { number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression) }
   var prefixedPhoneNumber: String { "+351" + number.cleanPhoneNumber }
   var hasPrefix: Bool { number.trimmingCharacters(in: .whitespaces).hasPrefix("+") }
   var hasSpaces: Bool { number.contains(where: { $0.isWhitespace }) }
   func hash(into hasher: inout Hasher) { hasher.combine(id) }
   static func == (lhs: PhoneNumberItem, rhs: PhoneNumberItem) -> Bool { lhs.id == rhs.id }
}

struct ContactItem: Identifiable {
   let id: String
   let contact: CNContact
   var phones: [PhoneNumberItem]
   var displayName: String { CNContactFormatter.string(from: contact, style: .fullName) ?? "Sem nome" }
   var hasDuplicates: Bool {
      let normalized = phones.map { $0.normalizedNumber }
      for i in 0..<normalized.count {
         for j in (i+1)..<normalized.count {
            let num1 = normalized[i]
            let num2 = normalized[j]
            if num1.hasSuffix(num2) || num2.hasSuffix(num1) { return true }
         }
      }
      return false
   }
   var needsAction: Bool { phones.contains { !$0.hasPrefix } || hasDuplicates }
}

// MARK: - Contact Manager

@MainActor
class ContactManager: ObservableObject {
   @Published var contacts: [ContactItem] = []
   @Published var isLoading = false
   @Published var statusMessage = ""
   @Published var hasError = false
   @Published var showPreview = false
   @Published var isProcessing = false

   nonisolated private let contactStore = CNContactStore()

   var contactsNeedingAction: Int { contacts.filter { $0.needsAction }.count }
   var hasSelectedActions: Bool {
      contacts.contains { contact in
         contact.phones.contains { $0.action != .skip }
      }
   }

   #if os(macOS)
   func requestAccess() async {
      // macOS não requer permissão de acesso aos contactos
      await loadContacts()
   }
   #else
   func requestAccess() async {
      do {
         let granted = try await contactStore.requestAccess(for: .contacts)
         if granted {
            await loadContacts()
         } else {
            statusMessage = "Acesso aos contactos negado. Por favor, autorize nas Definições do Sistema."
            hasError = true
         }
      } catch {
         statusMessage = "Erro ao solicitar acesso: \(error.localizedDescription)"
         hasError = true
      }
   }
   #endif

   static let keysToFetch: [CNKeyDescriptor] = [
      CNContactBirthdayKey,
      CNContactDatesKey,
      CNContactDepartmentNameKey,
      CNContactEmailAddressesKey,
      CNContactFamilyNameKey,
      CNContactGivenNameKey,
      CNContactIdentifierKey,
      CNContactImageDataAvailableKey,
      CNContactImageDataKey,
      CNContactInstantMessageAddressesKey,
      CNContactJobTitleKey,
      CNContactMiddleNameKey,
      CNContactNamePrefixKey,
      CNContactNameSuffixKey,
      CNContactNicknameKey,
      CNContactNonGregorianBirthdayKey,
      CNContactNoteKey,
      CNContactOrganizationNameKey,
      CNContactPhoneNumbersKey,
      CNContactPhoneticFamilyNameKey,
      CNContactPhoneticGivenNameKey,
      CNContactPhoneticMiddleNameKey,
      CNContactPhoneticOrganizationNameKey,
      CNContactPostalAddressesKey,
      CNContactPreviousFamilyNameKey,
      CNContactRelationsKey,
      CNContactSocialProfilesKey,
      CNContactThumbnailImageDataKey,
      CNContactTypeKey,
      CNContactUrlAddressesKey
   ] as [CNKeyDescriptor]

   private func getAllContactKeys() -> [CNKeyDescriptor] {
      ContactManager.keysToFetch + [CNContactFormatter.descriptorForRequiredKeys(for: .fullName)]
   }

   func loadContacts() async {
      isLoading = true
      statusMessage = "A carregar contactos..."
      let keysToFetch = getAllContactKeys()
      let request = CNContactFetchRequest(keysToFetch: keysToFetch)

      let store = contactStore

      let loadedContacts: [ContactItem] = await Task.detached(priority: .medium) {
         var contacts: [ContactItem] = []
         do {
            try store.enumerateContacts(with: request) { contact, _ in
               guard !contact.phoneNumbers.isEmpty else { return }
               let phoneItems = contact.phoneNumbers.map { labeledValue in
                  let number = labeledValue.value.stringValue
                  let label = CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: labeledValue.label ?? "")
                  return PhoneNumberItem(number: number, label: label)
               }
               let contactItem = ContactItem(
                  id: contact.identifier,
                  contact: contact,
                  phones: phoneItems
               )
               contacts.append(contactItem)
            }
         } catch {
            print("Erro ao carregar contactos: \(error)")
         }
         return contacts
      }.value

      contacts = loadedContacts.sorted { $0.displayName < $1.displayName }
      statusMessage = "✓ \(contacts.count) contactos carregados"
      hasError = false
      isLoading = false
   }

   func applyChanges() async {
      isProcessing = true
      statusMessage = "A processar alterações..."

      let snapshotContacts = contacts

      var successCount = 0
      var errorCount = 0
      var deletedCount = 0
      var prefixedCount = 0

      let result = await Task.detached(priority: .userInitiated) { () -> (success: Int, prefixed: Int, deleted: Int, errors: Int) in
         var localSuccess = 0
         var localErrors = 0
         var localDeleted = 0
         var localPrefixed = 0

         let saveRequest = CNSaveRequest()

         let store = CNContactStore()

         for contactItem in snapshotContacts {
            guard contactItem.phones.contains(where: { $0.action != .skip }) else { continue }

            do {
               let fullContact = try await store.unifiedContact(withIdentifier: contactItem.id, keysToFetch: ContactManager.keysToFetch)
               guard let mutableContact = fullContact.mutableCopy() as? CNMutableContact else { continue }

               var newPhoneNumbers: [CNLabeledValue<CNPhoneNumber>] = []
               for phoneItem in contactItem.phones {
                  switch phoneItem.action {
                  case .skip:
                     let existing = CNPhoneNumber(stringValue: phoneItem.number)
                     let labeledValue = CNLabeledValue(label: phoneItem.label, value: existing)
                     newPhoneNumbers.append(labeledValue)
                  case .addPrefix:
                     let newNumber = await phoneItem.prefixedPhoneNumber
                     let newPhoneNumber = CNPhoneNumber(stringValue: newNumber)
                     let labeledValue = CNLabeledValue(label: phoneItem.label, value: newPhoneNumber)
                     newPhoneNumbers.append(labeledValue)
                     localPrefixed += 1
                  case .removeSpaces:
                     let newNumber = await phoneItem.prefixedPhoneNumber
                     let existing = CNPhoneNumber(stringValue: newNumber)
                     let labeledValue = CNLabeledValue(label: phoneItem.label, value: existing)
                     newPhoneNumbers.append(labeledValue)
                  case .delete:
                     localDeleted += 1
                  }
               }
               mutableContact.phoneNumbers = newPhoneNumbers
               saveRequest.update(mutableContact)
               localSuccess += 1
            } catch {
               print("Erro ao preparar atualização de contacto: \(error)")
               localErrors += 1
            }
         }
         do {
            try store.execute(saveRequest)
         } catch {
            let fallbackStore = store
            localSuccess = 0
            for contactItem in snapshotContacts {
               guard contactItem.phones.contains(where: { $0.action != .skip }) else { continue }
               do {
                  let fullContact = try await fallbackStore.unifiedContact(withIdentifier: contactItem.id, keysToFetch: ContactManager.keysToFetch)
                  guard let mutableContact = fullContact.mutableCopy() as? CNMutableContact else { continue }

                  var newPhoneNumbers: [CNLabeledValue<CNPhoneNumber>] = []
                  for phoneItem in contactItem.phones {
                     switch phoneItem.action {
                     case .skip:
                        let existing = CNPhoneNumber(stringValue: phoneItem.number)
                        let labeledValue = CNLabeledValue(label: phoneItem.label, value: existing)
                        newPhoneNumbers.append(labeledValue)
                     case .addPrefix:
                        let newNumber = await phoneItem.prefixedPhoneNumber
                        let newPhoneNumber = CNPhoneNumber(stringValue: newNumber)
                        let labeledValue = CNLabeledValue(label: phoneItem.label, value: newPhoneNumber)
                        newPhoneNumbers.append(labeledValue)
                     case .removeSpaces:
                        let newNumber = await phoneItem.prefixedPhoneNumber
                        let existing = CNPhoneNumber(stringValue: newNumber)
                        let labeledValue = CNLabeledValue(label: phoneItem.label, value: existing)
                        newPhoneNumbers.append(labeledValue)
                     case .delete:
                        break
                     }
                  }
                  mutableContact.phoneNumbers = newPhoneNumbers
                  let perSave = CNSaveRequest()
                  perSave.update(mutableContact)
                  try fallbackStore.execute(perSave)
                  localSuccess += 1
               } catch {
                  print("Erro ao atualizar contacto (fallback): \(error)")
                  localErrors += 1
               }
            }
         }
         return (localSuccess, localPrefixed, localDeleted, localErrors)
      }.value

      successCount = result.success
      prefixedCount = result.prefixed
      deletedCount = result.deleted
      errorCount = result.errors

      let summary = """
       ✓ Processamento concluído:
       • \(successCount) contactos atualizados
       • \(prefixedCount) números com prefixo adicionado
       • \(deletedCount) números eliminados
       \(errorCount > 0 ? "• \(errorCount) erros" : "")
       """
      statusMessage = summary
      hasError = errorCount > 0
      isProcessing = false
      showPreview = false
      await loadContacts()
   }
   func autoDetectActions() {
      var updatedContacts = contacts
      for i in 0..<updatedContacts.count {
         var contact = updatedContacts[i]
         let normalized = contact.phones.map { $0.normalizedNumber }
         var normalizedToIndices: [String: [Int]] = [:]
         for (index, norm) in normalized.enumerated() {
            normalizedToIndices[norm, default: []].append(index)
         }
         for j in 0..<contact.phones.count {
            var phone = contact.phones[j]
            let currentNormalized = normalized[j]
            if let indices = normalizedToIndices[currentNormalized], indices.count > 1 {
               let hasPrefix = phone.hasPrefix
               let isFirstWithPrefix = indices.first(where: { contact.phones[$0].hasPrefix }) == j
               if !hasPrefix || !isFirstWithPrefix {
                  phone.action = .delete
                  contact.phones[j] = phone
                  continue
               }
            }
            var isDuplicateWithoutPrefix = false
            if !phone.hasPrefix {
               for k in 0..<contact.phones.count where k != j {
                  let otherNormalized = normalized[k]
                  let otherHasPrefix = contact.phones[k].hasPrefix
                  if otherHasPrefix && (otherNormalized.hasSuffix(currentNormalized) || currentNormalized.hasSuffix(otherNormalized)) {
                     isDuplicateWithoutPrefix = true
                     break
                  }
               }
            }
            if isDuplicateWithoutPrefix {
               phone.action = .delete
            } else if !phone.hasPrefix && !currentNormalized.hasPrefix("1") {
               phone.action = .addPrefix
            } else if phone.hasSpaces {
               phone.action = .removeSpaces
            } else {
               phone.action = .skip
            }
            contact.phones[j] = phone
         }
         updatedContacts[i] = contact
      }
      contacts = updatedContacts
      statusMessage = "✓ Ações detectadas automaticamente"
   }
   func updatePhoneAction(contactId: String, phoneId: UUID, action: PhoneAction) {
      guard let contactIndex = contacts.firstIndex(where: { $0.id == contactId }),
            let phoneIndex = contacts[contactIndex].phones.firstIndex(where: { $0.id == phoneId }) else {
         return
      }
      contacts[contactIndex].phones[phoneIndex].action = action
   }
}

extension String {
   subscript(i: Int) -> Character? {
      guard i >= 0 && i < self.count else { return nil }
      let index = self.index(self.startIndex, offsetBy: i)
      return self[index]
   }
   var cleanPhoneNumber: String {
      let digitsOnly = String(Int(self.components(separatedBy: .decimalDigits.inverted).joined()) ?? 0)
      return digitsOnly.hasPrefix("351") ? String(digitsOnly.dropFirst(3)) : digitsOnly
   }
   var portuguesePhoneNumber: String? {
      let number = self.cleanPhoneNumber
      guard number.count == 9 else { return nil }
      let finalRegex = "^([23789])\\d{8}$"
      var isValid = false
      do {
         let regex = try NSRegularExpression(pattern: finalRegex, options: .caseInsensitive)
         let range = NSRange(location: 0, length: number.utf16.count)
         isValid = regex.firstMatch(in: number, options: [], range: range) != nil
      } catch {
         print("Regex Error: \(error.localizedDescription)")
         isValid = false
      }
      guard isValid else { return nil }
      if String(number[0]!) == "9" {
         guard "1"..."6" ~= String(number[1]!) else { return nil }
      }
      return "+351" + number
   }
   var isPortuguesePhoneNumber: Bool {
      self.portuguesePhoneNumber != nil
   }
   func normalizedPortuguesePhoneNumber() -> String? {
      let digitsOnly = String(Int(self.components(separatedBy: .decimalDigits.inverted).joined()) ?? 0)
      let number = digitsOnly.hasPrefix("351") ? String(digitsOnly.dropFirst(3)) : digitsOnly
      guard number.count == 9 else { return nil }
      let validStartDigits = ["2", "3", "7", "8", "9"]
      guard let firstDigit = number.first,
            validStartDigits.contains(String(firstDigit)) else {
         return nil
      }
      if firstDigit == "9" {
         let secondDigit = number.dropFirst().first ?? "0"
         guard "1"..."6" ~= secondDigit else { return nil }
      }
      return "+351" + number
   }
}
