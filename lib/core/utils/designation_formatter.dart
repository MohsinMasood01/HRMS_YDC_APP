/// Utility class for formatting designations
/// 
/// Converts full designation names to shortened abbreviations
class DesignationFormatter {
  /// Shortens designation names according to business rules
  /// 
  /// Mapping:
  /// - Deputy General Manager -> DGM
  /// - General Manager -> GM
  /// - Assistant General Manager -> AGM
  /// - Deputy Manager -> DM
  /// - Assistant Manager -> AM
  /// 
  /// Returns the shortened form if mapping exists, otherwise returns original
  static String shortenDesignation(String designation) {
    if (designation.isEmpty) return designation;
    
    // Normalize the input (trim and handle case variations)
    final normalized = designation.trim();
    
    // Check for exact matches (case-insensitive)
    final lower = normalized.toLowerCase();
    
    if (lower.contains('deputy general manager') || lower.contains('deputy gm') || lower.contains('dy gm')|| lower.contains('dy general manager')) {
      return 'DGM';
    } else if (lower.contains('general manager') && !lower.contains('deputy') && !lower.contains('assistant') || lower.contains('gm')) {
      return 'GM';
    } else if (lower.contains('assistant general manager') || lower.contains('assistant gm') || lower.contains('asst gm') || lower.contains('asst general manager')) {
      return 'AGM';
    } else if (lower.contains('deputy manager') && !lower.contains('general') || lower.contains('dy manager')) {
      return 'DM';
    } else if (lower.contains('assistant manager') && !lower.contains('general') || lower.contains('asst manager')) {
      return 'AM';
    }
    
    // Return original if no mapping found
    return designation;
  }
}
