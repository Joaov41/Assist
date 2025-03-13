import PDFKit
import UniformTypeIdentifiers

class PDFHandler {
    static func extractText(from pdfData: Data) -> String {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return "" }
        var text = ""
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            text += page.string ?? ""
        }
        
        return text
    }
}
