//
//  SidebarView.swift
//  SystemVoiceMemos
//

import SwiftUI

// MARK: - Sidebar Types

enum SidebarItem: Hashable, Identifiable {
    case library(LibraryCategory)
    case folder(String)

    var id: Self { self }
}

enum LibraryCategory: String, CaseIterable, Identifiable {
    case all
    case favorites
    case recentlyDeleted

    var id: Self { self }

    var title: String {
        switch self {
        case .all: return "All Recordings"
        case .favorites: return "Favorites"
        case .recentlyDeleted: return "Recently Deleted"
        }
    }

    var icon: String {
        switch self {
        case .all: return "rectangle.stack"
        case .favorites: return "star"
        case .recentlyDeleted: return "trash"
        }
    }
}

// MARK: - Sidebar View

struct SidebarView: View {
    @Binding var selectedItem: SidebarItem?
    let folders: [String]
    let width: CGFloat
    var onDeleteFolder: ((String) -> Void)?
    var onRenameFolder: ((String) -> Void)?

    var body: some View {
        List(selection: $selectedItem) {
            Section {
                ForEach(LibraryCategory.allCases) { category in
                    Label {
                        Text(category.title)
                            .font(.system(size: 13))
                    } icon: {
                        Image(systemName: category.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(category == .all ? .blue : .secondary)
                    }
                    .tag(SidebarItem.library(category))
                }
            } header: {
                Text("Library")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            
            Section {
                if folders.isEmpty {
                    Text("No folders")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 20)
                } else {
                    ForEach(folders, id: \.self) { folder in
                        Label {
                            Text(folder)
                                .font(.system(size: 13))
                        } icon: {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.blue)
                        }
                        .tag(SidebarItem.folder(folder))
                        .contextMenu {
                            Button {
                                onRenameFolder?(folder)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                onDeleteFolder?(folder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Folders")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
        }
        .listStyle(.sidebar)
        .frame(width: width)
        .frame(maxHeight: .infinity)
    }
}
