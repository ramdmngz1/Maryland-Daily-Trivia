import SwiftUI
import UIKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Animated UIImageView from sprite sheet
struct AnimatedSpriteImageView: UIViewRepresentable {
    let frames: [UIImage]
    let frameDuration: Double
    let contentMode: UIView.ContentMode

    init(frames: [UIImage], frameDuration: Double = 0.12, contentMode: UIView.ContentMode = .scaleAspectFit) {
        self.frames = frames
        self.frameDuration = frameDuration
        self.contentMode = contentMode
    }

    func makeUIView(context: Context) -> UIImageView {
        let iv = UIImageView()
        iv.contentMode = contentMode
        iv.clipsToBounds = true
        configure(iv)
        return iv
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        configure(uiView)
    }

    private func configure(_ iv: UIImageView) {
        guard !frames.isEmpty else { return }
        iv.image = frames.first
        iv.animationImages = frames
        iv.animationDuration = frameDuration * Double(frames.count)
        iv.animationRepeatCount = 0
        if !iv.isAnimating { iv.startAnimating() }
    }
}

// MARK: - Blue Crab Sprite View (SwiftUI wrapper)
// Asset names: crab_walk_01 ... crab_walk_08 (8 frames, colorful blue crab)
// Fallback: crab_icon static image
struct BlueCrabSpriteView: View {
    var size: CGFloat
    var frameDuration: Double = 0.12
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let frames = (1...8).compactMap { i in
            UIImage(named: String(format: "crab_walk_%02d", i))
        }

        if frames.isEmpty {
            Image("crab_icon")
                .resizable()
                .scaledToFit()
                .frame(width: size)
                .colorMultiply(ColorTheme.accent)
        } else {
            AnimatedSpriteImageView(frames: frames, frameDuration: frameDuration)
                .frame(width: size, height: size)
                .accessibilityLabel("Blue crab animation")
        }
    }
}

// MARK: - Frame cache (NSCache-backed for memory pressure eviction)
final class CrabFramesCache {
    static let shared = CrabFramesCache()
    private let cache = NSCache<NSString, FramesCacheEntry>()
    private init() { cache.countLimit = 4 }

    func frames(for sheet: UIImage, across: Int, down: Int, total: Int?) -> [UIImage]? {
        guard let cg = sheet.cgImage else { return nil }
        let key = NSString(string: "\(cg.hashValue)-\(across)-\(down)-\(total ?? -1)")
        if let entry = cache.object(forKey: key) { return entry.frames }
        let framesOut = sliceFrames(from: sheet, across: across, down: down, total: total)
        cache.setObject(FramesCacheEntry(frames: framesOut), forKey: key)
        return framesOut
    }

    private class FramesCacheEntry: NSObject {
        let frames: [UIImage]
        init(frames: [UIImage]) { self.frames = frames }
    }

    private func sliceFrames(from sheet: UIImage, across: Int, down: Int, total: Int?) -> [UIImage] {
        guard let cg = sheet.cgImage else { return [] }
        let widthPx = cg.width / max(across, 1)
        let heightPx = cg.height / max(down, 1)
        var images: [UIImage] = []
        let totalCount = total ?? (across * down)
        for idx in 0..<totalCount {
            let row = idx / across; let col = idx % across
            let rect = CGRect(x: col * widthPx, y: row * heightPx, width: widthPx, height: heightPx)
            if let cropped = cg.cropping(to: rect) {
                images.append(UIImage(cgImage: cropped, scale: sheet.scale, orientation: .up))
            }
        }
        return images
    }
}

// Backward-compat alias so LoadingView and HomeView compile without changes
typealias ArmadilloSpriteView = BlueCrabSpriteView
