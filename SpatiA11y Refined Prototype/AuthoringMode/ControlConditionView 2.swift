import SwiftUI
import Combine
import UIKit

struct ControlConditionView: View {
    @ObservedObject var audioModel: AudioViewModel
    @StateObject private var store = ControlConditionStore()
    @State private var pendingAddType: PendingAddType?
    @State private var pendingRenameEntry: ControlEntry?
    @State private var pendingMoveEntry: ControlEntry?
    @State private var pendingDeleteEntry: ControlEntry?
    @State private var inputName = ""

    var body: some View {
        NavigationView {
            List {
                if let parentFolderName = store.parentFolderNameForCurrentFolder {
                    Section {
                        Button {
                            store.navigateToParent()
                        } label: {
                            Label("Back to \(parentFolderName)", systemImage: "chevron.left")
                        }
                        .accessibilityLabel("Back to \(parentFolderName)")
                        .accessibilityHint("Returns to the previous folder.")
                    }
                }

                let entries = store.entriesInCurrentFolder
                if entries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                        Text("No Items")
                            .font(.headline)
                        Text("Use Add to create a new item or folder.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .listRowBackground(Color.clear)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("No items in this folder. Use Add to create a new item or folder.")
                } else {
                    ForEach(entries) { entry in
                        row(for: entry)
                    }
                }
            }
            .navigationTitle(store.currentFolderTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Item", systemImage: "doc.badge.plus") {
                            pendingAddType = .item
                            inputName = ""
                        }
                        Button("New Folder", systemImage: "folder.badge.plus") {
                            pendingAddType = .folder
                            inputName = ""
                        }
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .accessibilityLabel("Add")
                    .accessibilityHint("Create a new item or folder.")
                }
            }
            .alert(addTitle, isPresented: addBinding) {
                TextField("Name", text: $inputName)
                Button("Cancel", role: .cancel) {
                    pendingAddType = nil
                }
                Button("Create") {
                    guard let type = pendingAddType else { return }
                    store.addEntry(named: inputName, kind: type.entryKind)
                    pendingAddType = nil
                    inputName = ""
                }
                .disabled(inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a name for the new \(pendingAddType?.rawValue ?? "entry").")
            }
            .alert("Rename", isPresented: renameBinding) {
                TextField("Name", text: $inputName)
                Button("Cancel", role: .cancel) {
                    pendingRenameEntry = nil
                }
                Button("Save") {
                    guard let entry = pendingRenameEntry else { return }
                    store.renameEntry(entryID: entry.id, to: inputName)
                    pendingRenameEntry = nil
                    inputName = ""
                }
                .disabled(inputName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Enter a new name.")
            }
            .confirmationDialog(
                "Move to folder",
                isPresented: moveBinding,
                titleVisibility: .visible
            ) {
                if let movingEntry = pendingMoveEntry {
                    ForEach(store.validMoveDestinations(for: movingEntry)) { folder in
                        Button(folder.pathDescription) {
                            store.moveEntry(entryID: movingEntry.id, to: folder.id)
                            pendingMoveEntry = nil
                        }
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingMoveEntry = nil
                }
            }
            .confirmationDialog(
                "Delete this entry?",
                isPresented: deleteBinding,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let entry = pendingDeleteEntry {
                        store.deleteEntry(entryID: entry.id)
                    }
                    pendingDeleteEntry = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteEntry = nil
                }
            } message: {
                Text("If you delete a folder, all items inside it are deleted too.")
            }
        }
        .onAppear {
            _ = audioModel.selectedScreen
        }
    }

    @ViewBuilder
    private func row(for entry: ControlEntry) -> some View {
        let content = rowContent(for: entry)

        if entry.kind == .folder {
            Button {
                store.openFolder(entry.id)
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.name)
            .accessibilityValue("Folder")
            .accessibilityHint("Opens the folder.")
            .accessibilityAddTraits(.isButton)
            .swipeActions {
                rowSwipeActions(for: entry)
            }
            .contextMenu {
                rowContextMenu(for: entry)
            }
        } else {
            content
                .accessibilityLabel(entry.name)
                .accessibilityValue("Item")
                .accessibilityHint("Actions available: rename, move, and delete.")
                .swipeActions {
                    rowSwipeActions(for: entry)
                }
                .contextMenu {
                    rowContextMenu(for: entry)
                }
        }
    }

    private func rowContent(for entry: ControlEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: entry.kind == .folder ? "folder.fill" : "doc.fill")
                .foregroundStyle(entry.kind == .folder ? .blue : .secondary)
            Text(entry.name)
                .lineLimit(2)
            Spacer()
            if entry.kind == .folder {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func rowSwipeActions(for entry: ControlEntry) -> some View {
        Button(role: .destructive) {
            pendingDeleteEntry = entry
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func rowContextMenu(for entry: ControlEntry) -> some View {
        Button("Rename", systemImage: "pencil") {
            pendingRenameEntry = entry
            inputName = entry.name
        }
        if store.canMove(entry) {
            Button("Move", systemImage: "folder") {
                pendingMoveEntry = entry
            }
        }
        Button("Delete", systemImage: "trash", role: .destructive) {
            pendingDeleteEntry = entry
        }
    }

    private var addTitle: String {
        pendingAddType == .folder ? "New Folder" : "New Item"
    }

    private var addBinding: Binding<Bool> {
        Binding(
            get: { pendingAddType != nil },
            set: { if !$0 { pendingAddType = nil } }
        )
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { pendingRenameEntry != nil },
            set: { if !$0 { pendingRenameEntry = nil } }
        )
    }

    private var moveBinding: Binding<Bool> {
        Binding(
            get: { pendingMoveEntry != nil },
            set: { if !$0 { pendingMoveEntry = nil } }
        )
    }

    private var deleteBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteEntry != nil },
            set: { if !$0 { pendingDeleteEntry = nil } }
        )
    }
}

private enum PendingAddType: String {
    case item
    case folder

    var entryKind: ControlEntryKind {
        self == .folder ? .folder : .item
    }
}

private enum ControlEntryKind: String, Codable {
    case folder
    case item

    var accessibilityType: String {
        self == .folder ? "folder" : "item"
    }
}

private struct ControlEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let kind: ControlEntryKind
    var parentID: UUID?
}

private struct FolderDestination: Identifiable {
    let id: UUID?
    let pathDescription: String
}

private struct ControlConditionSnapshot: Codable {
    let entries: [ControlEntry]
    let currentFolderID: UUID?
}

private final class ControlConditionStore: ObservableObject {
    @Published private(set) var entries: [ControlEntry] = []
    @Published private(set) var currentFolderID: UUID? = nil
    private let persistenceKey = "control_condition_snapshot_v1"

    init() {
        load()
    }

    var currentFolderTitle: String {
        currentFolder?.name ?? "Control Condition"
    }

    var parentFolderNameForCurrentFolder: String? {
        guard let current = currentFolder else { return nil }
        return current.parentID.flatMap(folderName(for:)) ?? "top level"
    }

    var entriesInCurrentFolder: [ControlEntry] {
        entries
            .filter { $0.parentID == currentFolderID }
            .sorted { lhs, rhs in
                if lhs.kind != rhs.kind {
                    return lhs.kind == .folder
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    private var currentFolder: ControlEntry? {
        guard let id = currentFolderID else { return nil }
        return entries.first(where: { $0.id == id })
    }

    func openFolder(_ id: UUID) {
        guard let folder = entries.first(where: { $0.id == id && $0.kind == .folder }) else { return }
        currentFolderID = folder.id
        save()
        announce("\(folder.name) opened")
    }

    func navigateToParent() {
        let previousFolderName = currentFolder?.name ?? "folder"
        currentFolderID = currentFolder?.parentID
        save()
        announce("Returned from \(previousFolderName)")
    }

    func addEntry(named rawName: String, kind: ControlEntryKind) {
        let name = normalizedName(from: rawName)
        guard !name.isEmpty else { return }

        let uniqueName = uniquedName(base: name, kind: kind, in: currentFolderID)
        let entry = ControlEntry(id: UUID(), name: uniqueName, kind: kind, parentID: currentFolderID)
        entries.append(entry)
        save()
        announce("\(entry.name) \(kind == .folder ? "folder" : "item") created")
    }

    func renameEntry(entryID: UUID, to rawName: String) {
        let name = normalizedName(from: rawName)
        guard !name.isEmpty else { return }
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }

        let source = entries[index]
        let uniqueName = uniquedName(base: name, kind: source.kind, in: source.parentID, excluding: source.id)
        entries[index].name = uniqueName
        save()
        announce("Renamed to \(uniqueName)")
    }

    func canMove(_ entry: ControlEntry) -> Bool {
        !validMoveDestinations(for: entry).isEmpty
    }

    func validMoveDestinations(for entry: ControlEntry) -> [FolderDestination] {
        var excludedIDs: Set<UUID> = [entry.id]
        if entry.kind == .folder {
            excludedIDs.formUnion(descendantFolderIDs(of: entry.id))
        }

        var destinations = [FolderDestination(id: nil, pathDescription: "On My iPad")]
        destinations += entries
            .filter { $0.kind == .folder && !excludedIDs.contains($0.id) }
            .map { folder in
                FolderDestination(id: folder.id, pathDescription: folderPath(folder.id))
            }
            .sorted { $0.pathDescription.localizedCaseInsensitiveCompare($1.pathDescription) == .orderedAscending }

        return destinations.filter { $0.id != entry.parentID }
    }

    func moveEntry(entryID: UUID, to destinationFolderID: UUID?) {
        guard let index = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let originalName = entries[index].name
        let kind = entries[index].kind
        let uniqueName = uniquedName(base: originalName, kind: kind, in: destinationFolderID, excluding: entryID)
        entries[index].parentID = destinationFolderID
        entries[index].name = uniqueName
        save()

        if destinationFolderID == nil {
            announce("\(entries[index].name) moved to top level")
        } else {
            announce("\(entries[index].name) moved")
        }
    }

    func deleteEntry(entryID: UUID) {
        guard let target = entries.first(where: { $0.id == entryID }) else { return }
        var idsToDelete: Set<UUID> = [entryID]
        if target.kind == .folder {
            idsToDelete.formUnion(descendantFolderIDs(of: entryID))
            let descendants = entries
                .filter { descendantParentIDs(of: $0.id).contains(entryID) }
                .map(\.id)
            idsToDelete.formUnion(descendants)
        }

        entries.removeAll { idsToDelete.contains($0.id) }

        if let active = currentFolderID, idsToDelete.contains(active) {
            currentFolderID = nil
        }
        save()
        announce("\(target.name) deleted")
    }

    private func folderName(for id: UUID) -> String? {
        entries.first(where: { $0.id == id })?.name
    }

    private func descendantFolderIDs(of folderID: UUID) -> Set<UUID> {
        var seen = Set<UUID>()
        var queue = [folderID]

        while let next = queue.popLast() {
            let children = entries.filter { $0.parentID == next && $0.kind == .folder }.map(\.id)
            for childID in children where !seen.contains(childID) {
                seen.insert(childID)
                queue.append(childID)
            }
        }
        return seen
    }

    private func descendantParentIDs(of entryID: UUID) -> [UUID] {
        var parentIDs: [UUID] = []
        var cursor = entries.first(where: { $0.id == entryID })?.parentID
        while let nextParent = cursor {
            parentIDs.append(nextParent)
            cursor = entries.first(where: { $0.id == nextParent })?.parentID
        }
        return parentIDs
    }

    private func folderPath(_ folderID: UUID) -> String {
        var names = [String]()
        var cursor: UUID? = folderID
        while let next = cursor, let folder = entries.first(where: { $0.id == next }) {
            names.append(folder.name)
            cursor = folder.parentID
        }
        return (["On My iPad"] + names.reversed()).joined(separator: " / ")
    }

    private func normalizedName(from rawName: String) -> String {
        rawName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func uniquedName(base: String, kind: ControlEntryKind, in parentID: UUID?, excluding excludedID: UUID? = nil) -> String {
        let siblings = entries
            .filter { $0.parentID == parentID && $0.kind == kind && $0.id != excludedID }
            .map { $0.name.lowercased() }

        guard siblings.contains(base.lowercased()) else { return base }

        var index = 2
        while siblings.contains("\(base) \(index)".lowercased()) {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func announce(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else { return }
        guard let snapshot = try? JSONDecoder().decode(ControlConditionSnapshot.self, from: data) else { return }
        entries = snapshot.entries
        currentFolderID = snapshot.currentFolderID
    }

    private func save() {
        let snapshot = ControlConditionSnapshot(entries: entries, currentFolderID: currentFolderID)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
}
