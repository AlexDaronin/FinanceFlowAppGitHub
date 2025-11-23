//
//  CategoryManagementView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI

struct CategoryManagementView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showAddCategory = false
    @State private var editingCategory: Category?
    @State private var searchText = ""
    
    private var filteredCategories: [Category] {
        if searchText.isEmpty {
            return settings.categories.sorted { $0.name < $1.name }
        }
        return settings.categories
            .filter { $0.name.localizedCaseInsensitiveContains(searchText) }
            .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        List {
            ForEach(filteredCategories) { category in
                CategoryRow(category: category) {
                    editingCategory = category
                } onDelete: {
                    deleteCategory(category)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.customBackground)
        .navigationTitle("Manage Categories")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search categories")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCategory = nil
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            CategoryFormView(
                category: editingCategory,
                onSave: { category in
                    if let editingCategory = editingCategory {
                        updateCategory(editingCategory, with: category)
                    } else {
                        addCategory(category)
                    }
                    showAddCategory = false
                    editingCategory = nil
                },
                onCancel: {
                    showAddCategory = false
                    editingCategory = nil
                }
            )
        }
        .onChange(of: editingCategory) { oldValue, newValue in
            showAddCategory = newValue != nil
        }
    }
    
    private func addCategory(_ category: Category) {
        settings.categories.append(category)
    }
    
    private func updateCategory(_ oldCategory: Category, with newCategory: Category) {
        if let index = settings.categories.firstIndex(where: { $0.id == oldCategory.id }) {
            settings.categories[index] = newCategory
        }
    }
    
    private func deleteCategory(_ category: Category) {
        settings.categories.removeAll { $0.id == category.id }
    }
}

struct CategoryRow: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: category.iconName)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }
            
            Text(category.name)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct CategoryFormView: View {
    let category: Category?
    let onSave: (Category) -> Void
    let onCancel: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedIcon: String
    @State private var showIconPicker = false
    
    init(category: Category?, onSave: @escaping (Category) -> Void, onCancel: @escaping () -> Void) {
        self.category = category
        self.onSave = onSave
        self.onCancel = onCancel
        
        _name = State(initialValue: category?.name ?? "")
        _selectedIcon = State(initialValue: category?.iconName ?? "ellipsis.circle.fill")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                    
                    Button {
                        showIconPicker = true
                    } label: {
                        HStack {
                            Text("Icon")
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: selectedIcon)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updatedCategory = Category(
                            id: category?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            iconName: selectedIcon
                        )
                        onSave(updatedCategory)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showIconPicker) {
                IconPickerView(
                    icons: CategoryIconLibrary.transactionIcons,
                    selectedIcon: $selectedIcon,
                    title: "Select Icon"
                )
            }
        }
        .presentationDetents([.large])
    }
}

struct IconPickerView: View {
    let icons: [String]
    @Binding var selectedIcon: String
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredIcons: [String] {
        if searchText.isEmpty {
            return icons
        }
        // Simple search - in a real app, you might want to search by icon meaning
        return icons.filter { icon in
            icon.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(filteredIcons, id: \.self) { iconName in
                        Button {
                            selectedIcon = iconName
                            dismiss()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(selectedIcon == iconName ? Color.accentColor.opacity(0.2) : Color.customSecondaryBackground)
                                    .frame(width: 60, height: 60)
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .foregroundStyle(selectedIcon == iconName ? Color.accentColor : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Color.customBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search icons")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

