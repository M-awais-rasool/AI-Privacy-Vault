import SwiftUI

struct SidebarView: View {
    @Binding var selectedCategory: Category
    @State private var hoverCategory: Category? = nil
    
    var body: some View {
        List(Category.allCases, selection: $selectedCategory) { category in
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(category == selectedCategory ? .white : category.color)
                    .frame(width: 28, height: 28)
                    .background(
                        ZStack {
                            if category == selectedCategory {
                                Circle().fill(category.color)
                            } else if hoverCategory == category {
                                Circle().fill(category.color.opacity(0.15))
                            }
                        }
                    )
                    .animation(.easeInOut(duration: 0.2), value: selectedCategory)
                    .animation(.easeInOut(duration: 0.1), value: hoverCategory)
                
                Text(category.rawValue)
                    .font(.system(size: 14, weight: category == selectedCategory ? .semibold : .regular))
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onHover { isHovered in
                hoverCategory = isHovered ? category : nil
            }
            .tag(category)
        }
        .listStyle(.sidebar)
    }
}

#Preview {
    SidebarView(selectedCategory: .constant(.all))
        .frame(width: 200)
}
