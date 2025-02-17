import AppKit
import UniformTypeIdentifiers

extension NSPasteboard {
    var hasPDF: Bool {
        // First, try reading URL objects to see if a file URL with a .pdf extension exists.
        if let urls = self.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            if urls.contains(where: { $0.pathExtension.lowercased() == "pdf" }) {
                return true
            }
        }
        // Fallback: check the available types.
        return types?.contains(where: { $0.rawValue.lowercased().contains("pdf") }) ?? false
    }
    
    var hasVideo: Bool {
        return types?.contains(where: {
            $0.rawValue.lowercased().contains("movie") ||
            $0.rawValue.lowercased().contains("video")
        }) ?? false
    }
    
    var hasImage: Bool {
        let imageTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("public.png"),
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.tiff"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("public.image")
        ]
        return types?.contains(where: { imageTypes.contains($0) }) ?? false
    }
    
    func readPDF() -> Data? {
        // First, try to obtain a PDF file URL using UTType.pdf.
        let pdfUTType = UTType.pdf.identifier
        let options: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingContentsConformToTypes: [pdfUTType]
        ]
        if let urls = self.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           let pdfURL = urls.first,
           pdfURL.pathExtension.lowercased() == "pdf",
           let data = try? Data(contentsOf: pdfURL) {
            return data
        }
        
        // Next, check for direct PDF data using known types.
        let pdfTypes: [NSPasteboard.PasteboardType] = [
            .pdf,
            NSPasteboard.PasteboardType("com.adobe.pdf")
        ]
        for type in pdfTypes {
            if let pdfData = self.data(forType: type) {
                return pdfData
            }
        }
        
        return nil
    }
    
    func readVideo() -> Data? {
        let videoTypes: [NSPasteboard.PasteboardType] = [
            NSPasteboard.PasteboardType("public.mpeg-4"),
            NSPasteboard.PasteboardType("com.apple.quicktime-movie"),
            NSPasteboard.PasteboardType("public.avi"),
            NSPasteboard.PasteboardType("public.movie")
        ]
        
        for type in videoTypes {
            if let videoData = self.data(forType: type) {
                return videoData
            }
        }
        
        let readingOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes: ["public.movie"]]
        if let urls = self.readObjects(forClasses: [NSURL.self], options: readingOptions) as? [URL],
           let firstURL = urls.first,
           VideoHandler.supportedFormats.contains(firstURL.pathExtension.lowercased()),
           let videoData = VideoHandler.getVideoData(from: firstURL) {
            return videoData
        }
        
        return nil
    }
}

extension NSPasteboard.PasteboardType {
    static let pdf = NSPasteboard.PasteboardType("com.adobe.pdf")
    static let video = NSPasteboard.PasteboardType("public.movie")
}
