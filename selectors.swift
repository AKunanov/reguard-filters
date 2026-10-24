// Drops the hiding selectors WebKit can't parse from converted rule files, in place.
//
//     swift selectors.swift rules.json...
//
// Safari turns each css-display-none rule into one style rule, and a selector list with a single selector it
// doesn't understand (extended syntax like :remove-class() or :matches-path(), a style block left in the
// selector) makes WebKit drop the whole rule, taking every other selector in it along. Each selector is
// parsed the way a style sheet parses it; the ones that fail are removed, and a rule left with none is
// removed too.

import AppKit
import WebKit

let files = CommandLine.arguments.dropFirst().map { URL(fileURLWithPath: $0) }
if files.isEmpty {
    print("usage: swift selectors.swift rules.json...")
    exit(2)
}

// For each selector list: null when it parses as it is, otherwise [the selectors that do parse, how many there were].
let checker = """
(lists) => {
  const sheet = new CSSStyleSheet();
  const parses = (selector) => {
    try { sheet.insertRule(selector + " { display: none !important; }"); sheet.deleteRule(0); return true; }
    catch (_) { return false; }
  };
  // Splits at top-level commas: not inside (), [] or quotes.
  const split = (list) => {
    const parts = []; let depth = 0, quote = null, start = 0;
    for (let i = 0; i < list.length; i++) {
      const c = list[i];
      if (quote) { if (c === "\\\\") i++; else if (c === quote) quote = null; continue; }
      if (c === '"' || c === "'") quote = c;
      else if (c === "(" || c === "[") depth++;
      else if (c === ")" || c === "]") depth--;
      else if (c === "," && depth === 0) { parts.push(list.slice(start, i).trim()); start = i + 1; }
    }
    parts.push(list.slice(start).trim());
    return parts.filter(Boolean);
  };
  return lists.map((list) => {
    if (parses(list)) return null;
    const parts = split(list);
    return [parts.filter(parses), parts.length];
  });
}
"""

final class Cleaner: NSObject, WKNavigationDelegate {
    let webView = WKWebView(frame: .zero)
    var failed = false

    func start() {
        webView.navigationDelegate = self
        webView.loadHTMLString("<!doctype html>", baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        clean(0)
    }

    func clean(_ index: Int) {
        guard index < files.count else {
            exit(failed ? 1 : 0)
        }
        let file = files[index]
        guard var rules = (try? JSONSerialization.jsonObject(with: Data(contentsOf: file))) as? [[String: Any]] else {
            print("\(file.lastPathComponent): not a rule list")
            failed = true
            return clean(index + 1)
        }
        let hiding = rules.indices.filter { ((rules[$0]["action"] as? [String: Any])?["type"] as? String) == "css-display-none" }
        let lists = hiding.map { (rules[$0]["action"] as! [String: Any])["selector"] as? String ?? "" }

        webView.callAsyncJavaScript("return (\(checker))(lists)", arguments: ["lists": lists], in: nil, in: .page) { result in
            guard case .success(let value) = result, let verdicts = value as? [Any] else {
                print("\(file.lastPathComponent): WebKit didn't answer: \(result)")
                self.failed = true
                return self.clean(index + 1)
            }
            var droppedSelectors = 0
            var emptied = Set<Int>()
            for (position, verdict) in verdicts.enumerated() {
                guard let pair = verdict as? [Any], let kept = pair[0] as? [String], let total = pair[1] as? Int else {
                    continue
                }
                let ruleIndex = hiding[position]
                droppedSelectors += total - kept.count
                if kept.isEmpty {
                    emptied.insert(ruleIndex)
                } else {
                    var action = rules[ruleIndex]["action"] as! [String: Any]
                    action["selector"] = kept.joined(separator: ", ")
                    rules[ruleIndex]["action"] = action
                }
            }
            rules = rules.enumerated().filter { !emptied.contains($0.offset) }.map { $0.element }
            do {
                try JSONSerialization.data(withJSONObject: rules, options: [.withoutEscapingSlashes, .sortedKeys]).write(to: file)
                print("\(file.lastPathComponent): \(droppedSelectors) selectors WebKit can't parse removed, \(emptied.count) rules left empty dropped")
            } catch {
                print("\(file.lastPathComponent): \(error)")
                self.failed = true
            }
            self.clean(index + 1)
        }
    }
}

_ = NSApplication.shared
let cleaner = Cleaner()
cleaner.start()
DispatchQueue.main.asyncAfter(deadline: .now() + 600) {
    print("timed out")
    exit(1)
}
NSApp.run()
