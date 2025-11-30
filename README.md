# ContactsEditor

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![macOS](https://img.shields.io/badge/macOS-13%2B-lightgrey.svg)
![License](https://img.shields.io/badge/License-Restricted-red.svg)

---

## 1. Project Title
**ContactsEditor** – macOS contact prefix manager and cleaner

---

## 2. Description
ContactsEditor is a macOS application built with **SwiftUI** that allows users to efficiently manage and edit their contact phone numbers. The app can:  
- Detect missing country prefixes (`+351`) for Portuguese numbers  
- Remove unnecessary spaces  
- Identify and handle duplicate phone numbers  
- Preview and apply changes safely

---

## 3. Requirements
- **macOS:** 13.0 or later  
- **Xcode:** 15.0 or later  
- **Swift:** 5.9 or later  

---

## 4. Installation
1. Clone the repository:  
```bash
git clone https://github.com/carlneto/ContactsEditor.git
```

2. Open `ContactsEditor.xcodeproj` in Xcode
3. Build and run the project (⌘R)

---

## 5. Usage

* Launch the app. The main window shows a list of contacts with phone numbers.
* **Auto-Detect Actions**: Automatically detect which numbers need prefix addition, space removal, or deletion.
* **Preview & Apply**: Preview all changes before applying them to your contacts.
* **Reload**: Refresh the contact list.

**Example of workflow:**

```swift
contactManager.autoDetectActions()  // Auto-detect actions for all contacts
contactManager.showPreview = true   // Show preview before applying
await contactManager.applyChanges() // Apply changes safely
```

---

## 6. Project Structure

```
ContactsEditor/
├── App/
│   ├── ContactsEditorApp.swift   // Entry point of the app
│   └── AppDelegate.swift         // App lifecycle management
├── Views/
│   ├── ContentView.swift         // Main view orchestrator
│   ├── HeaderView.swift          // Header with stats and actions
│   ├── ContactListView.swift     // List of contacts
│   ├── ContactRowView.swift      // Individual contact row
│   ├── PhoneRowView.swift        // Individual phone row
│   ├── PreviewView.swift         // Preview of changes
│   └── EmptyStateView.swift      // Empty state UI
├── Models/
│   ├── ContactItem.swift         // Contact data model
│   ├── PhoneNumberItem.swift     // Phone data model
│   └── PhoneAction.swift         // Enum for phone actions
├── Managers/
│   └── ContactManager.swift      // Core logic for managing contacts
└── Extensions/
    └── String+Phone.swift        // String utilities for phone normalization
```

---

## 7. Main Features

* ✅ Automatic detection of required actions for contacts
* ✅ Preview before applying changes
* ✅ Add country prefix to Portuguese phone numbers (`+351`)
* ✅ Remove spaces from phone numbers
* ✅ Detect and handle duplicates
* ✅ Safe and asynchronous updates to macOS contact store
* ✅ Responsive SwiftUI interface with dynamic progress updates

---

## 8. License

**Restricted Use License** – All rights reserved.

* **Prohibited:** modification, redistribution, reverse engineering, commercial use without written permission.
* **Permitted:** strictly personal, private, non-commercial use for evaluation and testing.
* Provided "as-is" without warranties; author not liable for damages.

For full details, see the LICENSE file included in this project.

---

## 9. Credits / Authors

* **Author:** © 2025 carlneto
* Developed in **SwiftUI** for macOS
* Inspired by common contact management challenges for Portuguese numbers
