//
//  CategoryManagementView.swift
//  FinanceFlow
//
//  Created by Aleksey Daronin on 17/11/2025.
//

import SwiftUI
import UIKit

// Cache for valid icons to prevent lag
private var iconCache: [String: Bool] = [:]

struct CategoryManagementView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var showAddCategory = false
    @State private var editingCategory: Category?
    @State private var searchText = ""
    @State private var expandedCategories: Set<UUID> = []
    @State private var selectedCategoryType: CategoryType = .expense
    
    private let deletedCategoriesKey = "deletedDefaultCategories"
    
    // Track deleted default categories by name+type
    private var deletedDefaultCategories: Set<String> {
        get {
            if let data = UserDefaults.standard.data(forKey: deletedCategoriesKey),
               let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
                return decoded
            }
            return []
        }
    }
    
    private func markCategoryAsDeleted(_ category: Category) {
        var deleted = deletedDefaultCategories
        deleted.insert(categoryKey(category))
        if let encoded = try? JSONEncoder().encode(deleted) {
            UserDefaults.standard.set(encoded, forKey: deletedCategoriesKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    private func categoryKey(_ category: Category) -> String {
        "\(category.name)|\(category.type.rawValue)"
    }
    
    private var filteredCategories: [Category] {
        // Start with saved categories
        var allCategories = settings.categories
        
        // Add defaults that aren't deleted and aren't already in saved categories
        let defaults = Category.defaultCategories
        let deleted = deletedDefaultCategories
        for defaultCat in defaults {
            let key = categoryKey(defaultCat)
            let isDeleted = deleted.contains(key)
            let exists = allCategories.contains { $0.name == defaultCat.name && $0.type == defaultCat.type }
            
            if !isDeleted && !exists {
                allCategories.append(defaultCat)
            }
        }
        
        if searchText.isEmpty {
            return allCategories.sorted { $0.name < $1.name }
        }
        return allCategories
            .filter { category in
                category.name.localizedCaseInsensitiveContains(searchText) ||
                category.subcategories.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            }
            .sorted { $0.name < $1.name }
    }
    
    private var displayedCategories: [Category] {
        filteredCategories.filter { $0.type == selectedCategoryType }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Category Type Switch
                Picker("", selection: $selectedCategoryType) {
                    Text(String(localized: "Income", comment: "Income")).tag(CategoryType.income)
                    Text(String(localized: "Expense", comment: "Expense")).tag(CategoryType.expense)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Categories List
                LazyVStack(spacing: 8) {
                    ForEach(displayedCategories) { category in
                        CategoryCard(
                            category: category,
                            isExpanded: expandedCategories.contains(category.id),
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if expandedCategories.contains(category.id) {
                                        expandedCategories.remove(category.id)
                                    } else {
                                        expandedCategories.insert(category.id)
                                    }
                                }
                            },
                            onEdit: {
                                // Ensure we have a valid category with all properties
                                let categoryToEdit = Category(
                                    id: category.id,
                                    name: category.name,
                                    iconName: category.iconName,
                                    colorName: category.colorName,
                                    type: category.type,
                                    subcategories: category.subcategories
                                )
                                editingCategory = categoryToEdit
                            },
                            onDelete: {
                                deleteCategory(category)
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color.customBackground)
        .navigationTitle(String(localized: "Categories", comment: "Categories title"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: String(localized: "Search categories", comment: "Search placeholder"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editingCategory = nil
                    showAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
        }
        .sheet(item: $editingCategory) { categoryToEdit in
            CategoryFormView(
                category: categoryToEdit,
                onSave: { newCategory in
                    updateCategory(categoryToEdit, with: newCategory)
                    editingCategory = nil
                },
                onCancel: {
                    editingCategory = nil
                },
                onDelete: {
                    deleteCategory(categoryToEdit)
                    editingCategory = nil
                }
            )
        }
        .sheet(isPresented: $showAddCategory) {
            CategoryFormView(
                category: nil,
                onSave: { category in
                    addCategory(category)
                    showAddCategory = false
                },
                onCancel: {
                    showAddCategory = false
                },
                onDelete: nil
            )
        }
    }
    
    private func addCategory(_ category: Category) {
        settings.categories.append(category)
    }
    
    private func updateCategory(_ oldCategory: Category, with newCategory: Category) {
        let categoryId = newCategory.id
        
        if let index = settings.categories.firstIndex(where: { $0.id == categoryId }) {
            var updated = settings.categories
            updated[index] = newCategory
            settings.categories = updated
        } else if let index = settings.categories.firstIndex(where: { $0.name == newCategory.name && $0.type == newCategory.type }) {
            var updated = settings.categories
            let existingId = updated[index].id
            updated[index] = Category(
                id: existingId,
                name: newCategory.name,
                iconName: newCategory.iconName,
                colorName: newCategory.colorName,
                type: newCategory.type,
                subcategories: newCategory.subcategories
            )
            settings.categories = updated
        } else {
            settings.categories.append(newCategory)
        }
    }
    
    private func deleteCategory(_ category: Category) {
        // Remove from settings.categories
        var updated = settings.categories
        updated.removeAll { $0.id == category.id }
        updated.removeAll { $0.name == category.name && $0.type == category.type }
        settings.categories = updated
        
        // If it's a default category, mark it as deleted to prevent re-adding
        let defaults = Category.defaultCategories
        if defaults.contains(where: { $0.name == category.name && $0.type == category.type }) {
            markCategoryAsDeleted(category)
        }
    }
}

struct CategoryCard: View {
    let category: Category
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main category row
            HStack(spacing: 12) {
                // Category icon - tappable to edit
                Button {
                    onEdit()
                } label: {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: category.iconName)
                            .font(.title3)
                            .foregroundStyle(category.color)
                    }
                }
                .buttonStyle(.plain)
                
                // Category name and info - tappable to edit
                Button {
                    onEdit()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 6) {
                            // Type badge
                            Text(category.type.displayName)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(category.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .foregroundStyle(category.type == .income ? .green : .red)
                                .clipShape(Capsule())
                            
                            // Subcategory count
                            if !category.subcategories.isEmpty {
                                Text("\(category.subcategories.count)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                
                // Expand/collapse button (only for categories with subcategories)
                if !category.subcategories.isEmpty {
                    Button {
                        onToggleExpand()
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.customCardBackground)
            
            // Subcategories (when expanded)
            if isExpanded && !category.subcategories.isEmpty {
                VStack(spacing: 0) {
                    ForEach(category.subcategories) { subcategory in
                        Divider()
                            .padding(.leading, 64)
                        
                        HStack(spacing: 10) {
                            // Subcategory icon
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.1))
                                    .frame(width: 28, height: 28)
                                Image(systemName: subcategory.iconName)
                                    .font(.caption)
                                    .foregroundStyle(category.color)
                            }
                            
                            Text(subcategory.name)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.customSecondaryBackground)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label(String(localized: "Edit", comment: "Edit"), systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "Delete", comment: "Delete"), systemImage: "trash")
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
    @State private var subcategories: [Subcategory]
    @State private var showIconPicker = false
    @State private var showDeleteConfirmation = false
    @State private var newSubcategoryName = ""
    @State private var showAddSubcategory = false
    @State private var showSubcategoryIconPicker = false
    @State private var iconPickerForSubcategoryId: UUID?
    @FocusState private var isSubcategoryNameFocused: Bool
    
    init(category: Category?, onSave: @escaping (Category) -> Void, onCancel: @escaping () -> Void, onDelete: (() -> Void)? = nil) {
        self.category = category
        self.onSave = onSave
        self.onCancel = onCancel
        self.onDelete = onDelete
        
        _name = State(initialValue: category?.name ?? "")
        _selectedIcon = State(initialValue: category?.iconName ?? "tag.fill")
        _selectedColorName = State(initialValue: category?.colorName ?? "blue")
        _selectedType = State(initialValue: category?.type ?? .expense)
        _subcategories = State(initialValue: category?.subcategories ?? [])
    }
    
    private var selectedColor: Color {
        CategoryColorLibrary.color(for: selectedColorName)
    }
    
    private var isEditMode: Bool {
        category != nil
    }
    
    private func saveCategory() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        let categoryId = category?.id ?? UUID()
        let updatedCategory = Category(
            id: categoryId,
            name: trimmedName,
            iconName: selectedIcon,
            colorName: selectedColorName,
            type: selectedType,
            subcategories: subcategories
        )
        
        onSave(updatedCategory)
        dismiss()
    }
    
    private func addSubcategory() {
        let trimmed = newSubcategoryName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        let exists = subcategories.contains { $0.name.lowercased() == trimmed.lowercased() }
        guard !exists else { return }
        
        let newSubcategory = Subcategory(name: trimmed, iconName: "tag.fill")
        var updated = subcategories
        updated.append(newSubcategory)
        subcategories = updated
        
        newSubcategoryName = ""
        showAddSubcategory = false
    }
    
    private func updateSubcategoryName(_ id: UUID, to newName: String) {
        guard let index = subcategories.firstIndex(where: { $0.id == id }) else { return }
        
        // Update name in real-time while typing
        var updated = subcategories
        updated[index].name = newName
        subcategories = updated
    }
    
    // Validate subcategory name when editing is done
    private func validateSubcategoryName(_ id: UUID) {
        guard let index = subcategories.firstIndex(where: { $0.id == id }) else { return }
        let currentName = subcategories[index].name
        let trimmed = currentName.trimmingCharacters(in: .whitespaces)
        
        var updated = subcategories
        
        // If empty, restore original or use default
        if trimmed.isEmpty {
            if let original = category?.subcategories.first(where: { $0.id == id }) {
                updated[index].name = original.name
            } else {
                updated[index].name = "Subcategory"
            }
            subcategories = updated
            return
        }
        
        // Check for duplicates
        let exists = subcategories.contains { $0.name.lowercased() == trimmed.lowercased() && $0.id != id }
        if exists {
            // Restore original if duplicate
            if let original = category?.subcategories.first(where: { $0.id == id }) {
                updated[index].name = original.name
            } else {
                updated[index].name = "Subcategory"
            }
            subcategories = updated
        } else {
            // Save trimmed name
            updated[index].name = trimmed
            subcategories = updated
        }
    }
    
    private func updateSubcategoryIcon(_ id: UUID, to iconName: String) {
        guard let index = subcategories.firstIndex(where: { $0.id == id }) else { return }
        var updated = subcategories
        updated[index].iconName = iconName
        subcategories = updated
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Category Icon Preview
                    Button {
                        showIconPicker = true
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(selectedColor)
                                    .frame(width: 100, height: 100)
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white)
                            }
                            Text(String(localized: "Tap to change icon", comment: "Icon hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    .buttonStyle(.plain)
                    
                    // Category Type
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Category Type", comment: "Type section"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("", selection: $selectedType) {
                            ForEach(CategoryType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                    }
                    
                    // Category Name
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Category Name", comment: "Name section"))
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextField(String(localized: "Enter category name", comment: "Name placeholder"), text: $name)
                            .font(.body)
                            .padding()
                            .background(Color.customCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal)
                    }
                    
                    // Subcategories Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(String(localized: "Subcategories", comment: "Subcategories"))
                                .font(.headline)
                            Spacer()
                            if !subcategories.isEmpty {
                                Text("\(subcategories.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                        
                        // Add Subcategory Button
                        Button {
                            showAddSubcategory = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(selectedColor)
                                Text(String(localized: "Add Subcategory", comment: "Add button"))
                                Spacer()
                            }
                            .padding()
                            .background(selectedColor.opacity(0.1))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.horizontal)
                        
                        // Subcategories List
                        if !subcategories.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(Array(subcategories.enumerated()), id: \.element.id) { index, subcategory in
                                    HStack(spacing: 12) {
                                        // Icon button
                                        Button {
                                            iconPickerForSubcategoryId = subcategory.id
                                            showSubcategoryIconPicker = true
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(selectedColor.opacity(0.15))
                                                    .frame(width: 40, height: 40)
                                                Image(systemName: subcategory.iconName)
                                                    .font(.title3)
                                                    .foregroundStyle(selectedColor)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                        
                                        // Name field - always editable
                                        TextField("Subcategory name", text: Binding(
                                            get: {
                                                guard index < subcategories.count else { return subcategory.name }
                                                return subcategories[index].name
                                            },
                                            set: { newValue in
                                                updateSubcategoryName(subcategory.id, to: newValue)
                                            }
                                        ))
                                        .textFieldStyle(.plain)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .focused($isSubcategoryNameFocused)
                                        .onSubmit {
                                            validateSubcategoryName(subcategory.id)
                                            isSubcategoryNameFocused = false
                                        }
                                        .onChange(of: isSubcategoryNameFocused) { isFocused in
                                            if !isFocused {
                                                validateSubcategoryName(subcategory.id)
                                            }
                                        }
                                        
                                        // Delete button
                                        Button(role: .destructive) {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                var updated = subcategories
                                                updated.removeAll { $0.id == subcategory.id }
                                                subcategories = updated
                                            }
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                                .font(.subheadline)
                                        }
                                    }
                                    .padding()
                                    .background(Color.customCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Save Button
                    Button {
                        saveCategory()
                    } label: {
                        HStack {
                            Spacer()
                            Text(String(localized: "Save", comment: "Save button"))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding()
                        .background(name.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray : selectedColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Color Picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text(String(localized: "Category Color", comment: "Color section"))
                            .font(.headline)
                            .padding(.horizontal)
                        
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
                        .padding(.horizontal)
                    }
                    
                    // Delete Button (Edit Mode Only)
                    if isEditMode, onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text(String(localized: "Delete Category", comment: "Delete button"))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.customBackground)
            .navigationTitle(category == nil ? String(localized: "New Category", comment: "New title") : String(localized: "Edit Category", comment: "Edit title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "Cancel", comment: "Cancel")) {
                    onCancel()
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save", comment: "Save")) {
                    saveCategory()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showIconPicker) {
            IconPickerView(
                icons: CategoryIconLibrary.transactionIcons,
                selectedIcon: $selectedIcon,
                selectedColor: selectedColor,
                title: String(localized: "Select Icon", comment: "Icon picker title")
            )
        }
        .alert(String(localized: "Add Subcategory", comment: "Add alert"), isPresented: $showAddSubcategory) {
            TextField(String(localized: "Subcategory name", comment: "Name placeholder"), text: $newSubcategoryName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button(String(localized: "Cancel", comment: "Cancel"), role: .cancel) {
                newSubcategoryName = ""
            }
            Button(String(localized: "Add", comment: "Add")) {
                addSubcategory()
            }
            .disabled(newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .sheet(isPresented: $showSubcategoryIconPicker) {
            if let subcategoryId = iconPickerForSubcategoryId {
                SimpleIconPickerView(
                    selectedIcon: Binding(
                        get: { subcategories.first(where: { $0.id == subcategoryId })?.iconName ?? "tag.fill" },
                        set: { updateSubcategoryIcon(subcategoryId, to: $0) }
                    ),
                    selectedColor: selectedColor
                )
                .onDisappear {
                    iconPickerForSubcategoryId = nil
                }
            }
        }
        .alert(String(localized: "Delete Category", comment: "Delete alert"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "Cancel", comment: "Cancel"), role: .cancel) { }
            Button(String(localized: "Delete", comment: "Delete"), role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text(String(localized: "Are you sure you want to delete this category? This action cannot be undone.", comment: "Delete message"))
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
    
    // Filter out invalid icons that don't exist in SF Symbols (cached)
    private var validIcons: [String] {
        icons.filter { iconName in
            if let cached = iconCache[iconName] {
                return cached
            }
            let isValid = UIImage(systemName: iconName) != nil
            iconCache[iconName] = isValid
            return isValid
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(validIcons, id: \.self) { iconName in
                        Button {
                            selectedIcon = iconName
                            dismiss()
                        } label: {
                            ZStack {
                                if selectedIcon == iconName {
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: 60, height: 60)
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.monochrome)
                                } else {
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
                    Button(String(localized: "Done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }
}

struct SimpleIconPickerView: View {
    @Binding var selectedIcon: String
    let selectedColor: Color
    @Environment(\.dismiss) private var dismiss
    
    private let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 16)
    ]
    
    // Filter out invalid icons that don't exist in SF Symbols (cached)
    private var validIcons: [String] {
        CategoryIconLibrary.transactionIcons.filter { iconName in
            if let cached = iconCache[iconName] {
                return cached
            }
            let isValid = UIImage(systemName: iconName) != nil
            iconCache[iconName] = isValid
            return isValid
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(validIcons, id: \.self) { iconName in
                        Button {
                            selectedIcon = iconName
                            dismiss()
                        } label: {
                            ZStack {
                                if selectedIcon == iconName {
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: 60, height: 60)
                                    Image(systemName: iconName)
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .symbolRenderingMode(.monochrome)
                                } else {
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
            .navigationTitle(String(localized: "Select Icon", comment: "Icon picker"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationContentInteraction(.scrolls)
    }
}
