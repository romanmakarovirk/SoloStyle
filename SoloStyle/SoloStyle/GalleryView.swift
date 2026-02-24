//
//  GalleryView.swift
//  SoloStyle
//
//  Portfolio gallery with before/after photos
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Photo Storage Manager

enum PhotoStorageManager {
    nonisolated(unsafe) private static var galleryDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Gallery", isDirectory: true)
    }

    nonisolated static func ensureDirectoryExists() {
        guard let directory = galleryDirectory else { return }
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    nonisolated static func savePhoto(_ image: UIImage, type: PhotoType, appointmentId: UUID) -> String? {
        ensureDirectoryExists()
        guard let directory = galleryDirectory,
              let data = image.jpegData(compressionQuality: 0.8) else { return nil }

        let filename = "\(appointmentId.uuidString)_\(type.rawValue).jpg"
        let fileURL = directory.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return filename
        } catch {
            print("Failed to save photo: \(error)")
            return nil
        }
    }

    nonisolated static func loadPhoto(filename: String) -> UIImage? {
        guard let directory = galleryDirectory else { return nil }
        let fileURL = directory.appendingPathComponent(filename)
        return UIImage(contentsOfFile: fileURL.path)
    }

    nonisolated static func deletePhoto(filename: String) {
        guard let directory = galleryDirectory else { return }
        let fileURL = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    enum PhotoType: String, Sendable {
        case before, after
    }
}

// MARK: - Gallery View

struct GalleryView: View {
    @Query(
        filter: #Predicate<Appointment> { $0.statusRaw == "completed" },
        sort: \Appointment.date,
        order: .reverse
    ) private var completedAppointments: [Appointment]

    @State private var selectedAppointment: Appointment?
    @State private var filterByClient: Client?
    @State private var showingFilter = false

    private var appointmentsWithPhotos: [Appointment] {
        completedAppointments.filter { $0.hasPhotos }
    }

    private var filteredAppointments: [Appointment] {
        if let client = filterByClient {
            return appointmentsWithPhotos.filter { $0.client?.id == client.id }
        }
        return appointmentsWithPhotos
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                if appointmentsWithPhotos.isEmpty {
                    EmptyStateView(
                        icon: "photo.on.rectangle.angled",
                        title: L.noPhotosYet,
                        subtitle: L.addPhotosHint
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: Design.Spacing.s),
                            GridItem(.flexible(), spacing: Design.Spacing.s)
                        ], spacing: Design.Spacing.s) {
                            ForEach(filteredAppointments, id: \.id) { appointment in
                                GalleryCard(appointment: appointment)
                                    .onTapGesture {
                                        HapticManager.selection()
                                        selectedAppointment = appointment
                                    }
                            }
                        }
                        .padding(Design.Spacing.m)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle(L.portfolio)
            .toolbar {
                if !appointmentsWithPhotos.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button {
                                filterByClient = nil
                            } label: {
                                HStack {
                                    Text(L.allClients)
                                    Spacer()
                                    if filterByClient == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }

                            Divider()

                            let clients = Set(appointmentsWithPhotos.compactMap { $0.client })
                            ForEach(Array(clients), id: \.id) { client in
                                Button {
                                    filterByClient = client
                                } label: {
                                    HStack {
                                        Text(client.name)
                                        Spacer()
                                        if filterByClient?.id == client.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                        }
                    }
                }
            }
            .sheet(item: $selectedAppointment) { appointment in
                GalleryDetailView(appointment: appointment)
            }
        }
    }
}

// MARK: - Gallery Card

struct GalleryCard: View {
    let appointment: Appointment

    var body: some View {
        VStack(spacing: 0) {
            // Photos
            ZStack {
                if let afterPath = appointment.afterPhotoPath,
                   let image = PhotoStorageManager.loadPhoto(filename: afterPath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                } else if let beforePath = appointment.beforePhotoPath,
                          let image = PhotoStorageManager.loadPhoto(filename: beforePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Design.Colors.backgroundSecondary)
                        .aspectRatio(1, contentMode: .fill)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundStyle(Design.Colors.textTertiary)
                        }
                }

                // Before/After badge
                if appointment.beforePhotoPath != nil && appointment.afterPhotoPath != nil {
                    VStack {
                        HStack {
                            Spacer()
                            Text(L.beforeAfterBadge)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Design.Colors.accentPrimary, in: Capsule())
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }

            // Info
            VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                Text(appointment.client?.name ?? L.client)
                    .font(Design.Typography.caption1)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Text(appointment.service?.name ?? L.service)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(Design.Colors.textSecondary)
                    .lineLimit(1)

                Text(appointment.date, style: .date)
                    .font(Design.Typography.caption2)
                    .foregroundStyle(Design.Colors.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Design.Spacing.s)
            .background(Design.Colors.backgroundSecondary)
        }
        .clipShape(RoundedRectangle(cornerRadius: Design.Radius.m))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

// MARK: - Gallery Detail View

struct GalleryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let appointment: Appointment

    @State private var showingBeforeAfter = true

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Before/After comparison
                        if appointment.beforePhotoPath != nil && appointment.afterPhotoPath != nil {
                            BeforeAfterComparison(appointment: appointment)
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.l))
                        } else {
                            // Single photo
                            if let path = appointment.afterPhotoPath ?? appointment.beforePhotoPath,
                               let image = PhotoStorageManager.loadPhoto(filename: path) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: Design.Radius.l))
                            }
                        }

                        // Info card
                        GlassCard {
                            VStack(spacing: Design.Spacing.m) {
                                HStack {
                                    VStack(alignment: .leading, spacing: Design.Spacing.xxs) {
                                        Text(L.client)
                                            .font(Design.Typography.caption1)
                                            .foregroundStyle(Design.Colors.textTertiary)
                                        Text(appointment.client?.name ?? "—")
                                            .font(Design.Typography.headline)
                                    }

                                    Spacer()

                                    if let tier = appointment.client?.loyaltyTier {
                                        LoyaltyBadge(tier: tier, size: .medium)
                                    }
                                }

                                Divider()

                                HStack {
                                    InfoColumn(title: L.service, value: appointment.service?.name ?? "—")
                                    InfoColumn(title: L.date, value: appointment.formattedDate)
                                    InfoColumn(title: L.price, value: appointment.service?.formattedPrice ?? "—")
                                }
                            }
                        }
                        .padding(.horizontal, Design.Spacing.m)

                        // Share button
                        GlassButton(title: L.sharePhoto, icon: "square.and.arrow.up", isFullWidth: true) {
                            sharePhoto()
                        }
                        .padding(.horizontal, Design.Spacing.m)
                    }
                    .padding(.vertical, Design.Spacing.m)
                }
            }
            .navigationTitle(L.workDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.done) { dismiss() }
                }
            }
        }
    }

    private func sharePhoto() {
        guard let path = appointment.afterPhotoPath ?? appointment.beforePhotoPath,
              let image = PhotoStorageManager.loadPhoto(filename: path) else { return }

        let text = L.shareText(service: appointment.service?.name ?? L.service, client: appointment.client?.name ?? L.client)
        let activityVC = UIActivityViewController(activityItems: [image, text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

struct InfoColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(Design.Typography.caption2)
                .foregroundStyle(Design.Colors.textTertiary)
            Text(value)
                .font(Design.Typography.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Before/After Comparison

struct BeforeAfterComparison: View {
    let appointment: Appointment

    @State private var sliderPosition: CGFloat = 0.5
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // After image (bottom layer)
                if let afterPath = appointment.afterPhotoPath,
                   let afterImage = PhotoStorageManager.loadPhoto(filename: afterPath) {
                    Image(uiImage: afterImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }

                // Before image (clipped)
                if let beforePath = appointment.beforePhotoPath,
                   let beforeImage = PhotoStorageManager.loadPhoto(filename: beforePath) {
                    Image(uiImage: beforeImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .mask(
                            Rectangle()
                                .frame(width: geometry.size.width * sliderPosition)
                                .offset(x: -geometry.size.width * (1 - sliderPosition) / 2)
                        )
                }

                // Slider line
                Rectangle()
                    .fill(.white)
                    .frame(width: 3)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)

                // Slider handle
                Circle()
                    .fill(.white)
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .overlay {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Image(systemName: "chevron.right")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.gray)
                    }
                    .position(x: geometry.size.width * sliderPosition, y: geometry.size.height / 2)
                    .scaleEffect(isDragging ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3), value: isDragging)

                // Labels
                VStack {
                    Spacer()
                    HStack {
                        Text(L.beforeLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(8)

                        Spacer()

                        Text(L.afterLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: Capsule())
                            .padding(8)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let newPosition = value.location.x / geometry.size.width
                        sliderPosition = min(max(newPosition, 0.05), 0.95)
                    }
            )
        }
    }
}

// MARK: - Add Photo View

struct AddPhotoView: View {
    @Environment(\.dismiss) private var dismiss
    let appointment: Appointment

    @State private var beforeItem: PhotosPickerItem?
    @State private var afterItem: PhotosPickerItem?
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Design.Colors.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Design.Spacing.l) {
                        // Before photo
                        PhotoPickerSection(
                            title: L.beforeSection,
                            selectedItem: $beforeItem,
                            image: $beforeImage,
                            existingPath: appointment.beforePhotoPath
                        )
                        .animateOnAppear(delay: 0.1)

                        // After photo
                        PhotoPickerSection(
                            title: L.afterSection,
                            selectedItem: $afterItem,
                            image: $afterImage,
                            existingPath: appointment.afterPhotoPath
                        )
                        .animateOnAppear(delay: 0.2)

                        // Save button
                        GlassButton(title: L.savePhotos, icon: "checkmark", isFullWidth: true, isLoading: isSaving) {
                            savePhotos()
                        }
                        .disabled(beforeImage == nil && afterImage == nil && appointment.beforePhotoPath == nil && appointment.afterPhotoPath == nil)
                        .padding(.horizontal, Design.Spacing.m)
                        .animateOnAppear(delay: 0.3)
                    }
                    .padding(.vertical, Design.Spacing.m)
                }
            }
            .navigationTitle(L.addPhotos)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel) { dismiss() }
                }
            }
        }
    }

    private func savePhotos() {
        isSaving = true
        HapticManager.impact(.medium)

        let appointmentId = appointment.id
        let beforeImg = beforeImage
        let afterImg = afterImage

        Task.detached(priority: .userInitiated) {
            let beforePath: String? = if let before = beforeImg {
                PhotoStorageManager.savePhoto(before, type: .before, appointmentId: appointmentId)
            } else {
                nil
            }

            let afterPath: String? = if let after = afterImg {
                PhotoStorageManager.savePhoto(after, type: .after, appointmentId: appointmentId)
            } else {
                nil
            }

            await MainActor.run { [beforePath, afterPath] in
                if let path = beforePath {
                    appointment.beforePhotoPath = path
                }
                if let path = afterPath {
                    appointment.afterPhotoPath = path
                }
                isSaving = false
                HapticManager.notification(.success)
                dismiss()
            }
        }
    }
}

struct PhotoPickerSection: View {
    let title: String
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var image: UIImage?
    let existingPath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.s) {
            Text(title)
                .font(Design.Typography.headline)
                .padding(.horizontal, Design.Spacing.m)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else if let path = existingPath,
                              let existing = PhotoStorageManager.loadPhoto(filename: path) {
                        Image(uiImage: existing)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                    } else {
                        Rectangle()
                            .fill(Design.Colors.backgroundSecondary)
                            .frame(height: 200)
                            .overlay {
                                VStack(spacing: Design.Spacing.s) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 32))
                                    Text(L.tapToAddPhoto)
                                        .font(Design.Typography.subheadline)
                                }
                                .foregroundStyle(Design.Colors.textTertiary)
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Design.Radius.m))
            }
            .padding(.horizontal, Design.Spacing.m)
            .onChange(of: selectedItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        image = uiImage
                    }
                }
            }
        }
    }
}

#Preview {
    GalleryView()
        .modelContainer(for: Appointment.self, inMemory: true)
}
