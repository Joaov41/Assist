import Foundation

enum WritingOption: String, Identifiable {
    case coding = "Coding"
    
    var id: String { rawValue }
    
    var systemPrompt: String {
        """
        You are a coding assistant. Based on the user's instructions and provided code context, \
        generate or rewrite code to implement the desired functionality. \
        Output ONLY the code with no additional comments or explanations. \
        If the input is completely incompatible (e.g., totally random gibberish), \
        output "ERROR_TEXT_INCOMPATIBLE_WITH_REQUEST".
        """
    }
    
    var icon: String {
        "chevron.left.slash.chevron.right"  // SF Symbol for coding
    }
}
