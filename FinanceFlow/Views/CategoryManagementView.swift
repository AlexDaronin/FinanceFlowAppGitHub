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
        .navigationTitle(Text("Manage Categories", comment: "Category management title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text("Search categories", comment: "Search categories placeholder"))
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
                },
                onDelete: editingCategory != nil ? {
                    if let editingCategory = editingCategory {
                        deleteCategory(editingCategory)
                    }
                    showAddCategory = false
                    editingCategory = nil
                } : nil
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
        Button {
            onEdit()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: category.iconName)
                        .font(.headline)
                        .foregroundStyle(category.color)
                }
                
                Text(category.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "Delete", comment: "Delete action"), systemImage: "trash")
            }
        }
    }
}

struct CategoryFormView: View {
    let category: Category?
    let onSave: (Category) -> Void
    let onCancel: () -> Void
    let onDelete: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColorName: String
    @State private var selectedType: CategoryType
    @State private var showIconPicker = false
    @State private var showDeleteConfirmation = false
    
    init(category: Category?, onSave: @escaping (Category) -> Void, onCancel: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.category = category
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        _name = State(initialValue: category?.name ?? "")
        _selectedIcon = State(initialValue: category?.iconName ?? "ellipsis.circle.fill")
        _selectedColorName = State(initialValue: category?.colorName ?? "blue")
        _selectedType = State(initialValue: category?.type ?? .expense)
    }
    
    private var selectedColor: Color {
        CategoryColorLibrary.color(for: selectedColorName)
    }
    
    private var isEditMode: Bool {
        category != nil
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Top: Category Type (Income/Expense picker)
                Section(String(localized: "Category Type", comment: "Category type section")) {
                    Picker(String(localized: "Type", comment: "Category type picker"), selection: $selectedType) {
                        ForEach(CategoryType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Category Name (Large, clean text field)
                Section {
                    TextField(String(localized: "Category Name", comment: "Category name placeholder"), text: $name)
                        .font(.body)
                }
                
                // Middle: Icon Preview (Large circle with selected icon and color)
                Section {
                    Button {
                        showIconPicker = true
                    } label: {
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(selectedColor)
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white)
                            }
                            
                            Text(String(localized: "Tap to change icon", comment: "Icon preview hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .buttonStyle(.plain)
                }
                
                // Bottom: Color Picker grid
                Section(String(localized: "Category Color", comment: "Category color section")) {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(CategoryColorLibrary.availableColors, id: \.name) { colorOption in
                            Button {
                                selectedColorName = colorOption.name
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(colorOption.color)
                                        .frame(width: 44, height: 44)
                                    
                                    if selectedColorName == colorOption.name {
                                        Circle()
                                            .stroke(Color.white, lineWidth: 3)
                                            .frame(width: 44, height: 44)
                                        
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                // Delete button section (only in edit mode)
                if isEditMode, onDelete != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(String(localized: "Delete Category", comment: "Delete category button"))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .background(Color.customBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle(category == nil ? String(localized: "Add Category", comment: "Add category title") : String(localized: "Edit Category", comment: "Edit category title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel", comment: "Cancel button")) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save", comment: "Save button")) {
                        let updatedCategory = Category(
                            id: category?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            iconName: selectedIcon,
                            colorName: selectedColorName,
                            type: selectedType
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
                    selectedColor: selectedColor,
                    title: String(localized: "Select Icon", comment: "Select icon title")
                )
            }
            .alert(String(localized: "Delete Category", comment: "Delete category alert title"), isPresented: $showDeleteConfirmation) {
                Button(String(localized: "Cancel", comment: "Cancel button"), role: .cancel) { }
                Button(String(localized: "Delete", comment: "Delete button"), role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text(String(localized: "Are you sure you want to delete this category? This action cannot be undone.", comment: "Delete category confirmation message"))
            }
        }
        .presentationDetents([.large])
    }
}

struct IconPickerView: View {
    let icons: [String]
    @Binding var selectedIcon: String
    let selectedColor: Color
    let title: String
    @Environment(\.dismiss) private var dismiss
    
    init(icons: [String], selectedIcon: Binding<String>, selectedColor: Color = .blue, title: String) {
        self.icons = icons
        self._selectedIcon = selectedIcon
        self.selectedColor = selectedColor
        self.title = title
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(icons, id: \.self) { iconName in
                        Button {
                            selectedIcon = iconName
                            dismiss()
                        } label: {
                            ZStack {
                                if selectedIcon == iconName {
                                    // Selected: white icon inside filled circle with category color
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.monochrome)
                                } else {
                                    // Unselected: adaptive icon color inside transparent circle with visible border
                                    Circle()
                                        .fill(Color.clear)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                        )
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                        .symbolRenderingMode(.monochrome)
                                }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }
}

