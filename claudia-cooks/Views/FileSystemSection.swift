//
//  FileSystemSection.swift
//  claudia-cooks
//

import AppKit
import PDFKit
import SwiftUI

struct FileSystemSection: View {
    let recipes: [SavedRecipe]
    let selectedRecipeID: UUID?
    let pdfData: (SavedRecipe) -> Data?
    let isBlank: (SavedRecipe) -> Bool
    let fileURL: (SavedRecipe) -> URL?
    let libraryFolderURL: URL
    let onSelectRecipe: (SavedRecipe) -> Void
    let onDeleteRecipe: (SavedRecipe) -> Void
    let onAddMore: () -> Void

    @State private var recipePendingDeletion: SavedRecipe?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if recipes.isEmpty {
                emptyState
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recipes) { recipe in
                            recipeCard(recipe)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 4)
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)
            }
        }
        .padding(.vertical, 16)
        .background {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.regularMaterial)
                    .frame(height: 28)
                    .offset(y: -28)

                Rectangle()
                    .fill(.regularMaterial)
            }
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [.black.opacity(0.1), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 18)
            .allowsHitTesting(false)
        }
        .alert(
            "Delete Recipe?",
            isPresented: deleteConfirmationIsPresented,
            presenting: recipePendingDeletion
        ) { recipe in
            Button("Delete", role: .destructive) {
                onDeleteRecipe(recipe)
                recipePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                recipePendingDeletion = nil
            }
        } message: { recipe in
            Text("Are you sure you want to delete \"\(recipe.title)\"? This cannot be undone.")
        }
    }

    private var deleteConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { recipePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    recipePendingDeletion = nil
                }
            }
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label("File System", systemImage: "folder.fill")
                .font(.headline)

            Spacer()

            Button {
                onAddMore()
            } label: {
                Label("Add more", systemImage: "plus")
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 24)
    }

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Recipes you generate will appear here.")
                    .font(.subheadline.weight(.semibold))

                Text("Use Add more to start another framework when you are ready.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.separator.opacity(0.3), lineWidth: 1)
        }
        .padding(.horizontal, 24)
    }

    private func recipeCard(_ recipe: SavedRecipe) -> some View {
        let isSelected = selectedRecipeID == recipe.id
        let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return HStack(spacing: 12) {
            PDFThumbnailView(
                data: pdfData(recipe),
                framework: recipe.framework,
                isBlank: isBlank(recipe)
            )
            .frame(width: 56, height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: recipe.framework.icon)
                        .foregroundStyle(recipe.framework.accentColor)

                    Text(recipe.framework.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(recipe.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(relativeDate(for: recipe.updatedAt))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: 230, height: 96, alignment: .leading)
        .glassEffect(
            .regular.tint(recipe.framework.accentColor.opacity(isSelected ? 0.28 : 0.12)).interactive(),
            in: cardShape
        )
        .overlay {
            cardShape
                .strokeBorder(recipe.framework.accentColor.opacity(isSelected ? 0.55 : 0.18), lineWidth: 1)
        }
        .contentShape(cardShape)
        .onTapGesture {
            onSelectRecipe(recipe)
        }
        .contextMenu {
            Button {
                showInFinder(recipe)
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Button(role: .destructive) {
                recipePendingDeletion = recipe
            } label: {
                Label("Delete…", systemImage: "trash")
            }
        }
    }

    private func showInFinder(_ recipe: SavedRecipe) {
        let url = fileURL(recipe) ?? libraryFolderURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func relativeDate(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct PDFThumbnailView: View {
    let data: Data?
    let framework: RecipeFramework
    var isBlank: Bool = false

    var body: some View {
        Group {
            if isBlank {
                BlankPageView(framework: framework, style: .thumbnail)
            } else if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .background(.white)
            } else {
                Image(systemName: "doc.richtext")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.background.opacity(0.65))
            }
        }
    }

    private var thumbnailImage: NSImage? {
        guard let data else {
            return nil
        }

        return PDFDocument.from(data: data)?
            .firstPageThumbnail(size: CGSize(width: 112, height: 148))
    }
}

#Preview {
    FileSystemSection(
        recipes: [],
        selectedRecipeID: nil,
        pdfData: { _ in nil },
        isBlank: { _ in true },
        fileURL: { _ in nil },
        libraryFolderURL: FileManager.default.temporaryDirectory,
        onSelectRecipe: { _ in },
        onDeleteRecipe: { _ in },
        onAddMore: {}
    )
    .frame(width: 900)
}
