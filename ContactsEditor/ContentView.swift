import SwiftUI

// MARK: - Views

struct ContentView: View {
   @State private var contactManager = ContactManager()
   var body: some View {
      NavigationView {
         VStack(spacing: 0) {
            // Header
            HeaderView(contactManager: contactManager)
            Divider()
            // Contact List
            if contactManager.isLoading {
               ProgressView("A carregar contactos...")
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if contactManager.contacts.isEmpty {
               EmptyStateView()
            } else {
               ContactListView(contactManager: contactManager)
            }
         }
         .navigationTitle("Gestor de Prefixos")
      }
      .sheet(isPresented: $contactManager.showPreview) {
         PreviewView(contactManager: contactManager)
      }
      .task {
         await contactManager.requestAccess()
      }
   }
}

struct HeaderView: View {
   var contactManager: ContactManager
   var body: some View {
      VStack(spacing: 16) {
         HStack {
            VStack(alignment: .leading, spacing: 4) {
               Text("Contactos a processar: \(contactManager.contactsNeedingAction)")
                  .font(.headline)
               Text("Total de contactos: \(contactManager.contacts.count)")
                  .font(.caption)
                  .foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 12) {
               Button("Auto-Detectar") {
                  contactManager.autoDetectActions()
               }
               .buttonStyle(.bordered)
               Button("Pré-visualizar e Aplicar") {
                  contactManager.showPreview = true
               }
               .buttonStyle(.borderedProminent)
               .disabled(!contactManager.hasSelectedActions)

               Button("Recarregar") {
                  Task {
                     await contactManager.loadContacts()
                  }
               }
               .buttonStyle(.bordered)
            }
         }
         if !contactManager.statusMessage.isEmpty {
            HStack {
               Image(systemName: contactManager.hasError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                  .foregroundColor(contactManager.hasError ? .red : .green)
               Text(contactManager.statusMessage)
                  .font(.caption)
                  .foregroundColor(contactManager.hasError ? .red : .green)
               Spacer()
            }
            .padding(8)
            .background(contactManager.hasError ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
            .cornerRadius(8)
         }
      }
      .padding()
   }
}

struct ContactListView: View {
   var contactManager: ContactManager
   var body: some View {
      ScrollView {
         LazyVStack(spacing: 12) {
            ForEach(contactManager.contacts) { contact in
               ContactRowView(contact: contact, contactManager: contactManager)
            }
         }
         .padding()
      }
   }
}

struct ContactRowView: View {
   let contact: ContactItem
   var contactManager: ContactManager
   var body: some View {
      VStack(alignment: .leading, spacing: 12) {
         // Contact name header
         HStack {
            Text(contact.displayName)
               .font(.headline)
            Spacer()
            if contact.hasDuplicates {
               Text("Duplicados")
                  .font(.caption2)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.red.opacity(0.2))
                  .foregroundColor(.red)
                  .cornerRadius(4)
            }
            if contact.needsAction {
               Image(systemName: "exclamationmark.circle.fill")
                  .foregroundColor(.yellow)
            }
         }
         // Phone numbers
         ForEach(contact.phones) { phone in
            PhoneRowView(
               phone: phone,
               contactId: contact.id,
               contactManager: contactManager
            )
         }
      }
      .padding()
      .background(contact.needsAction ? Color.yellow.opacity(0.1) : Color.gray.opacity(0.05))
      .cornerRadius(12)
   }
}

struct PhoneRowView: View {
   let phone: PhoneNumberItem
   let contactId: String
   var contactManager: ContactManager
   var backgroundColor: Color {
      switch phone.action {
      case .skip: Color.clear
      case .addPrefix: Color.green.opacity(0.1)
      case .removeSpaces: Color.blue.opacity(0.1)
      case .delete: Color.red.opacity(0.1)
      }
   }
   var body: some View {
      VStack(alignment: .leading, spacing: 8) {
         HStack {
            VStack(alignment: .leading, spacing: 4) {
               HStack {
                  Text(phone.label)
                     .font(.caption)
                     .foregroundColor(.secondary)
                  if !phone.hasPrefix {
                     Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                  }
               }
               Text(phone.number)
                  .font(.system(.body, design: .monospaced))
               // Preview of change
               if phone.action == .addPrefix {
                  HStack(spacing: 4) {
                     Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.green)
                     Text(phone.prefixedPhoneNumber)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                  }
               } else if phone.action == .removeSpaces {
                  HStack(spacing: 4) {
                     Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                     Text(phone.prefixedPhoneNumber)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.blue)
                  }
               } else if phone.action == .delete {
                  Text("Será eliminado")
                     .font(.caption)
                     .foregroundColor(.red)
               }
            }
            Spacer()
            // Action buttons
            HStack(spacing: 8) {
               ForEach(PhoneAction.allCases, id: \.self) { action in
                  // Don't show "Add Prefix" button if phone already has prefix
                  if action == .addPrefix && phone.hasPrefix {
                     EmptyView()
                  } else if action == .removeSpaces && !phone.hasSpaces {
                     EmptyView()
                  } else {
                     ActionButton(action: action, isSelected: phone.action == action) {
                        contactManager.updatePhoneAction(contactId: contactId, phoneId: phone.id, action: action)
                     }
                  }
               }
            }
         }
      }
      .padding(12)
      .background(backgroundColor)
      .cornerRadius(8)
   }
}

struct ActionButton: View {
   let action: PhoneAction
   let isSelected: Bool
   let onTap: () -> Void
   var icon: String {
      switch action {
      case .skip: "xmark"
      case .addPrefix: "plus"
      case .removeSpaces: "minus"
      case .delete: "trash"
      }
   }
   var color: Color {
      switch action {
      case .skip: .gray
      case .addPrefix: .green
      case .removeSpaces: .blue
      case .delete: .red
      }
   }
   var body: some View {
      Button(action: onTap) {
         HStack(spacing: 4) {
            Image(systemName: icon)
               .font(.caption)
            Text(action.rawValue)
               .font(.caption)
         }
         .padding(.horizontal, 10)
         .padding(.vertical, 6)
         .background(isSelected ? color : .clear)
         .foregroundColor(isSelected ? .black : color)
         .cornerRadius(6)
         .overlay(
            RoundedRectangle(cornerRadius: 6)
               .stroke(color, lineWidth: 1)
         )
      }
      .buttonStyle(.plain)
   }
}

struct PreviewView: View {
   var contactManager: ContactManager
   @Environment(\.dismiss) var dismiss
   var changedContacts: [ContactItem] {
      contactManager.contacts.filter { contact in
         contact.phones.contains { $0.action != .skip }
      }
   }
   var body: some View {
      VStack(spacing: 0) {
         // Header
         HStack {
            Text("Pré-visualização das Alterações")
               .font(.title2)
               .fontWeight(.bold)
            Spacer()
            Button {
               dismiss()
            } label: {
               Image(systemName: "xmark.circle.fill")
                  .font(.title2)
                  .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
         }
         .padding()
         Divider()
         // Content
         if changedContacts.isEmpty {
            VStack(spacing: 16) {
               Image(systemName: "checkmark.circle")
                  .font(.system(size: 48))
                  .foregroundColor(.gray)
               Text("Nenhuma alteração selecionada")
                  .font(.headline)
                  .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
         } else {
            ScrollView {
               LazyVStack(alignment: .leading, spacing: 16) {
                  ForEach(changedContacts) { contact in
                     VStack(alignment: .leading, spacing: 12) {
                        Text(contact.displayName)
                           .font(.headline)

                        ForEach(contact.phones) { phone in
                           if phone.action != .skip {
                              PreviewPhoneRow(phone: phone)
                           }
                        }
                     }
                     .padding()
                     .background(Color.gray.opacity(0.05))
                     .cornerRadius(12)
                  }
               }
               .padding()
            }
         }
         Divider()
         // Footer buttons
         HStack(spacing: 12) {
            Button("Cancelar") {
               dismiss()
            }
            .buttonStyle(.bordered)
            Spacer()
            Button {
               Task {
                  await contactManager.applyChanges()
               }
            } label: {
               if contactManager.isProcessing {
                  ProgressView()
                     .controlSize(.small)
                     .padding(.horizontal, 8)
               } else {
                  HStack {
                     Image(systemName: "checkmark.circle.fill")
                     Text("Aplicar Alterações")
                  }
               }
            }
            .buttonStyle(.borderedProminent)
            .disabled(contactManager.isProcessing || changedContacts.isEmpty)
         }
         .padding()
      }
      .frame(width: 700, height: 600)
   }
}

struct PreviewPhoneRow: View {
   let phone: PhoneNumberItem
   var body: some View {
      HStack(spacing: 12) {
         Image(systemName: iconStr)
            .foregroundColor(color)
         if phone.action == .delete {
            Text(phone.number)
               .font(.system(.body, design: .monospaced))
               .strikethrough()
               .foregroundColor(.red)
            Text("Será eliminado")
               .font(.caption)
               .foregroundColor(.red)
         } else if phone.action == .addPrefix {
            Text(phone.number)
               .font(.system(.body, design: .monospaced))
               .foregroundColor(.secondary)
            Image(systemName: "arrow.right")
               .font(.caption)
               .foregroundColor(.green)
            Text(phone.prefixedPhoneNumber)
               .font(.system(.body, design: .monospaced))
               .foregroundColor(.green)
               .fontWeight(.medium)
         } else if phone.action == .removeSpaces {
            Text(phone.number)
               .font(.system(.body, design: .monospaced))
               .foregroundColor(.secondary)
            Image(systemName: "arrow.right")
               .font(.caption)
               .foregroundColor(.blue)
            Text(phone.prefixedPhoneNumber)
               .font(.system(.body, design: .monospaced))
               .foregroundColor(.blue)
               .fontWeight(.medium)
         }
         Spacer()
      }
      .padding(12)
      .background(color.opacity(0.1))
      .cornerRadius(8)
   }
   var iconStr: String {
      switch phone.action {
      case .skip: "equal.circle.fill"
      case .addPrefix: "plus.circle.fill"
      case .removeSpaces: "minus.circle.fill"
      case .delete: "trash.fill"
      }
   }
   var color: Color {
      switch phone.action {
      case .skip: .secondary
      case .addPrefix: .green
      case .removeSpaces: .blue
      case .delete: .red
      }
   }
}

struct EmptyStateView: View {
   var body: some View {
      VStack(spacing: 16) {
         Image(systemName: "person.crop.circle.badge.questionmark")
            .font(.system(size: 64))
            .foregroundColor(.gray)
         Text("Nenhum contacto encontrado")
            .font(.title2)
            .fontWeight(.medium)
         Text("Verifique as permissões de acesso aos contactos nas Definições do Sistema")
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
   }
}
