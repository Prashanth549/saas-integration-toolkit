"""
Log File Analyzer
Parses server logs and extracts errors, patterns, and insights
"""

import re
import sys
from datetime import datetime
from collections import Counter, defaultdict
from pathlib import Path

class LogAnalyzer:
    """Analyzes log files for errors and patterns"""
    
    # Log level patterns
    LOG_LEVELS = ['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL']
    
    # Common error patterns
    ERROR_PATTERNS = {
        'timeout': r'timeout|timed out',
        'connection': r'connection (refused|reset|closed|failed)',
        'auth': r'authentication|unauthorized|403|401',
        'not_found': r'not found|404',
        'server_error': r'500|internal server error',
        'database': r'database|sql|query (failed|error)',
    }
    
    def __init__(self, log_file_path):
        self.log_file = Path(log_file_path)
        self.entries = []
        self.errors = []
        self.warnings = []
        
        if not self.log_file.exists():
            raise FileNotFoundError(f"Log file not found: {log_file_path}")
    
    def parse_log_file(self):
        """Parse the log file and extract entries"""
        print(f"📄 Parsing log file: {self.log_file.name}")
        print("=" * 70)
        
        with open(self.log_file, 'r', encoding='utf-8', errors='ignore') as f:
            for line_num, line in enumerate(f, 1):
                line = line.strip()
                if not line:
                    continue
                
                entry = self._parse_log_line(line, line_num)
                if entry:
                    self.entries.append(entry)
                    
                    if entry['level'] == 'ERROR':
                        self.errors.append(entry)
                    elif entry['level'] == 'WARNING':
                        self.warnings.append(entry)
        
        print(f"✅ Parsed {len(self.entries)} log entries")
        print(f"   - Errors: {len(self.errors)}")
        print(f"   - Warnings: {len(self.warnings)}")
        print("=" * 70)
    
    def _parse_log_line(self, line, line_num):
        """Parse a single log line"""
        # Try common log formats
        
        # Format 1: [TIMESTAMP] LEVEL - MESSAGE
        pattern1 = r'\[([^\]]+)\]\s+(\w+)\s+-\s+(.+)'
        match = re.match(pattern1, line)
        
        if match:
            timestamp_str, level, message = match.groups()
            try:
                timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
            except:
                timestamp = None
            
            return {
                'line_num': line_num,
                'timestamp': timestamp,
                'level': level.upper(),
                'message': message,
                'raw': line
            }
        
        # Format 2: TIMESTAMP LEVEL MESSAGE
        pattern2 = r'(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(\w+)\s+(.+)'
        match = re.match(pattern2, line)
        
        if match:
            timestamp_str, level, message = match.groups()
            try:
                timestamp = datetime.strptime(timestamp_str, '%Y-%m-%d %H:%M:%S')
            except:
                timestamp = None
            
            return {
                'line_num': line_num,
                'timestamp': timestamp,
                'level': level.upper(),
                'message': message,
                'raw': line
            }
        
        # Fallback: treat as INFO
        return {
            'line_num': line_num,
            'timestamp': None,
            'level': 'INFO',
            'message': line,
            'raw': line
        }
    
    def analyze_errors(self):
        """Analyze error patterns"""
        if not self.errors:
            print("✨ No errors found - all clear!")
            return
        
        print("\n" + "=" * 70)
        print("🔍 ERROR ANALYSIS")
        print("=" * 70)
        
        # Categorize errors
        categorized = defaultdict(list)
        uncategorized = []
        
        for error in self.errors:
            message_lower = error['message'].lower()
            matched = False
            
            for category, pattern in self.ERROR_PATTERNS.items():
                if re.search(pattern, message_lower):
                    categorized[category].append(error)
                    matched = True
                    break
            
            if not matched:
                uncategorized.append(error)
        
        # Print categorized errors
        for category, errors in sorted(categorized.items(), key=lambda x: len(x[1]), reverse=True):
            print(f"\n{category.upper().replace('_', ' ')} ({len(errors)} occurrences):")
            print("-" * 70)
            for error in errors[:5]:  # Show first 5
                timestamp = error['timestamp'].strftime('%Y-%m-%d %H:%M:%S') if error['timestamp'] else 'Unknown'
                print(f"  [{timestamp}] {error['message'][:100]}")
            
            if len(errors) > 5:
                print(f"  ... and {len(errors) - 5} more")
        
        # Show uncategorized
        if uncategorized:
            print(f"\nOTHER ERRORS ({len(uncategorized)} occurrences):")
            print("-" * 70)
            for error in uncategorized[:3]:
                timestamp = error['timestamp'].strftime('%Y-%m-%d %H:%M:%S') if error['timestamp'] else 'Unknown'
                print(f"  [{timestamp}] {error['message'][:100]}")
    
    def analyze_patterns(self):
        """Analyze log patterns and statistics"""
        print("\n" + "=" * 70)
        print("📊 LOG STATISTICS")
        print("=" * 70)
        
        # Count by level
        level_counts = Counter(entry['level'] for entry in self.entries)
        print("\nLog Levels:")
        for level in self.LOG_LEVELS:
            count = level_counts.get(level, 0)
            bar = '█' * min(count, 50)
            print(f"  {level:10} {count:5} {bar}")
        
        # Timeline analysis
        if any(e['timestamp'] for e in self.entries):
            timestamps = [e['timestamp'] for e in self.entries if e['timestamp']]
            if timestamps:
                earliest = min(timestamps)
                latest = max(timestamps)
                duration = latest - earliest
                
                print(f"\nTime Range:")
                print(f"  Earliest: {earliest.strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"  Latest:   {latest.strftime('%Y-%m-%d %H:%M:%S')}")
                print(f"  Duration: {duration}")
        
        # Most common messages (excluding timestamps)
        message_patterns = Counter()
        for entry in self.entries:
            # Remove numbers and timestamps for pattern matching
            pattern = re.sub(r'\d{4}-\d{2}-\d{2}', 'DATE', entry['message'])
            pattern = re.sub(r'\d{2}:\d{2}:\d{2}', 'TIME', pattern)
            pattern = re.sub(r'\d+', 'N', pattern)
            message_patterns[pattern[:100]] += 1
        
        print("\nMost Common Message Patterns:")
        for pattern, count in message_patterns.most_common(5):
            print(f"  ({count}x) {pattern}")
    
    def generate_report(self):
        """Generate comprehensive analysis report"""
        self.parse_log_file()
        self.analyze_patterns()
        self.analyze_errors()
        
        print("\n" + "=" * 70)
        print("✅ Analysis Complete")
        print("=" * 70)

def main():
    """Main execution"""
    if len(sys.argv) < 2:
        print("Usage: python log_analyzer.py <log_file_path>")
        print("\nExample:")
        print("  python log_analyzer.py ../logs/sample.log")
        sys.exit(1)
    
    log_file = sys.argv[1]
    
    try:
        analyzer = LogAnalyzer(log_file)
        analyzer.generate_report()
    except FileNotFoundError as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()