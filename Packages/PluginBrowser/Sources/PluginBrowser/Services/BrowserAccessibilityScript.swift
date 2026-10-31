import Foundation

/// 页面内可访问性树的提取脚本。
///
/// 设计要点：
///
/// - **一份脚本，两种操作**（`snapshot` / `find`）。两者共用同一套 role 映射与
///   accessible name 计算，避免两份实现随时间产生分歧。
/// - **角色映射遵循 HTML-AAM**：`role` 属性优先，其次按标签名推导隐式角色。
/// - **名称计算遵循 accname 的实用子集**：`aria-labelledby` → `aria-label` →
///   关联 `<label>` → 内容文本 → `title` → `placeholder`。
/// - **ref 写回 DOM**（`data-lumi-browser-ref`）。属性挂在元素自身，页面没变时
///   元素还在，ref 就还在，因此跨快照天然稳定。
enum BrowserAccessibilityScript {
    /// 生成执行指定操作的脚本。
    ///
    /// - Parameters:
    ///   - operation: `snapshot` 或 `find`。
    ///   - options: 追加到脚本顶部的 JSON 配置。
    static func script(operation: String, options: [String: Any] = [:]) -> String {
        var config = options
        config["op"] = operation
        guard let data = try? JSONSerialization.data(withJSONObject: config),
              let json = String(data: data, encoding: .utf8) else {
            return "({})"
        }
        return "const __OPTS = \(json);\n" + body
    }

    private static let body = #"""
    (() => {
      const OPTS = __OPTS;
      const REF_ATTR = "data-lumi-browser-ref";
      const MAX_NODES = OPTS.maxNodes || 600;
      const MAX_DEPTH = OPTS.maxDepth || 30;
      const STATE = (window.__lumiBrowserState = window.__lumiBrowserState || { counter: 0 });

      const SENSITIVE = ["token", "access_token", "api_key", "apikey", "key", "password",
                         "passwd", "secret", "code", "signature", "sig", "auth"];

      // ---------------------------------------------------------------------
      // 可见性
      // ---------------------------------------------------------------------
      const isHidden = (el) => {
        if (!el || el.nodeType !== 1) return true;
        const tag = el.tagName;
        if (tag === "SCRIPT" || tag === "STYLE" || tag === "NOSCRIPT" || tag === "TEMPLATE") return true;
        if (el.hasAttribute("hidden")) return true;
        if (el.getAttribute("aria-hidden") === "true") return true;
        const cs = getComputedStyle(el);
        if (cs) {
          if (cs.display === "none" || cs.visibility === "hidden" || cs.visibility === "collapse") return true;
        }
        return el.getClientRects().length === 0;
      };

      // ---------------------------------------------------------------------
      // 角色
      // ---------------------------------------------------------------------
      const implicitRole = (el) => {
        const tag = el.tagName.toLowerCase();
        switch (tag) {
          case "a": return el.hasAttribute("href") ? "link" : null;
          case "area": return el.hasAttribute("href") ? "link" : null;
          case "button": return "button";
          case "input": {
            const type = (el.getAttribute("type") || "text").toLowerCase();
            if (type === "hidden") return null;
            if (type === "checkbox") return "checkbox";
            if (type === "radio") return "radio";
            if (type === "button" || type === "submit" || type === "reset" || type === "image") return "button";
            if (type === "range") return "slider";
            if (type === "number") return "spinbutton";
            if (type === "search") return "searchbox";
            if (type === "email" || type === "tel" || type === "url" || type === "text" || type === "password") return "textbox";
            return "textbox";
          }
          case "textarea": return "textbox";
          case "select": return (el.multiple || (el.size && el.size > 1)) ? "listbox" : "combobox";
          case "option": return "option";
          case "optgroup": return "group";
          case "img": return el.getAttribute("alt") === "" ? "presentation" : "img";
          case "svg": return "img";
          case "h1": case "h2": case "h3": case "h4": case "h5": case "h6": return "heading";
          case "ul": case "ol": return "list";
          case "li": return "listitem";
          case "dl": return "list";
          case "table": return "table";
          case "thead": return "rowgroup";
          case "tbody": return "rowgroup";
          case "tfoot": return "rowgroup";
          case "tr": return "row";
          case "td": return "cell";
          case "th": return el.getAttribute("scope") === "row" ? "rowheader" : "columnheader";
          case "caption": return "caption";
          case "nav": return "navigation";
          case "main": return "main";
          case "header": return "banner";
          case "footer": return "contentinfo";
          case "aside": return "complementary";
          case "form": return "form";
          case "section": return el.hasAttribute("aria-label") || el.hasAttribute("aria-labelledby") ? "region" : null;
          case "article": return "article";
          case "dialog": return "dialog";
          case "hr": return "separator";
          case "fieldset": return "group";
          case "legend": return null;
          case "label": return null;
          case "p": return null;
          case "details": return "group";
          case "summary": return "button";
          case "progress": return "progressbar";
          case "meter": return "meter";
          case "output": return "status";
          case "search": return "search";
          default: return null;
        }
      };

      const roleOf = (el) => {
        const explicit = el.getAttribute("role");
        if (explicit) {
          const first = explicit.trim().split(/\s+/)[0];
          if (first) return first.toLowerCase();
        }
        return implicitRole(el);
      };

      // 纯容器角色：保留结构但不进入可访问性树，避免 div 噪声淹没真正的交互元素。
      const SKIP_ROLES = new Set(["generic", "paragraph", "presentation", "none"]);

      // ---------------------------------------------------------------------
      // 名称
      // ---------------------------------------------------------------------
      const textOf = (el) => {
        let out = "";
        for (const node of el.childNodes) {
          if (node.nodeType === 3) {
            out += " " + node.nodeValue;
          } else if (node.nodeType === 1) {
            out += " " + textOf(node);
          }
        }
        return out.replace(/\s+/g, " ").trim();
      };

      const accessibleName = (el) => {
        const labelledBy = el.getAttribute("aria-labelledby");
        if (labelledBy) {
          const parts = [];
          for (const id of labelledBy.split(/\s+/)) {
            if (!id) continue;
            const target = document.getElementById(id);
            if (!target) continue;
            const label = target.getAttribute("aria-label") || textOf(target);
            if (label) parts.push(label);
          }
          if (parts.length) return parts.join(" ").replace(/\s+/g, " ").trim();
        }

        const ariaLabel = el.getAttribute("aria-label");
        if (ariaLabel && ariaLabel.trim()) return ariaLabel.trim();

        const tag = el.tagName.toLowerCase();
        if (tag === "img" || tag === "area") {
          const alt = el.getAttribute("alt");
          if (alt !== null) return alt.trim();
        }

        if (tag === "input" || tag === "textarea" || tag === "select") {
          if (el.labels) {
            for (const lb of Array.from(el.labels)) {
              const label = (lb.getAttribute("aria-label") || textOf(lb)).trim();
              if (label) return label;
            }
          }
          const wrapper = el.closest("label");
          if (wrapper) {
            const label = (wrapper.getAttribute("aria-label") || textOf(wrapper)).trim();
            if (label) return label;
          }
          const placeholder = el.getAttribute("placeholder");
          if (placeholder && placeholder.trim()) return placeholder.trim();
          const title = el.getAttribute("title");
          if (title && title.trim()) return title.trim();
          return "";
        }

        const content = textOf(el);
        if (content) return content;

        const title = el.getAttribute("title");
        if (title && title.trim()) return title.trim();
        const placeholder = el.getAttribute("placeholder");
        if (placeholder && placeholder.trim()) return placeholder.trim();
        return "";
      };

      // ---------------------------------------------------------------------
      // 值与链接
      // ---------------------------------------------------------------------
      const redactURL = (raw) => {
        if (!raw) return "";
        try {
          const url = new URL(raw, location.href);
          for (const key of Array.from(url.searchParams.keys())) {
            if (SENSITIVE.indexOf(key.toLowerCase()) !== -1) url.searchParams.set(key, "[redacted]");
          }
          url.hash = "";
          return url.href;
        } catch (_) {
          return raw;
        }
      };

      const valueOf = (el) => {
        const tag = el.tagName.toLowerCase();
        if (tag === "input") {
          const type = (el.getAttribute("type") || "text").toLowerCase();
          if (type === "password") return "[password]";
          if (type === "hidden") return "";
          return el.value ? String(el.value) : "";
        }
        if (tag === "textarea") return el.value ? String(el.value) : "";
        if (tag === "select") {
          if (el.multiple) {
            return Array.from(el.selectedOptions || []).map((o) => o.textContent || "").join(", ");
          }
          return el.selectedOptions && el.selectedOptions.length ? (el.selectedOptions[0].textContent || "") : "";
        }
        const ariaValue = el.getAttribute("aria-valuetext") || el.getAttribute("aria-valuenow");
        return ariaValue ? ariaValue : "";
      };

      const hrefOf = (el) => {
        const tag = el.tagName.toLowerCase();
        if (tag === "a" || tag === "area") {
          const href = el.getAttribute("href");
          return href ? redactURL(el.href || href) : "";
        }
        return "";
      };

      // ---------------------------------------------------------------------
      // 状态
      // ---------------------------------------------------------------------
      const ariaBool = (el, name) => {
        const value = el.getAttribute(name);
        if (value === null) return null;
        if (value === "true") return true;
        if (value === "false") return false;
        return null;
      };

      const stateOf = (el, role) => {
        const state = {};
        state.disabled = el.hasAttribute("disabled") || ariaBool(el, "aria-disabled") === true;

        if (role === "checkbox" || role === "radio" || role === "switch" || role === "menuitemcheckbox") {
          const aria = ariaBool(el, "aria-checked");
          if (aria !== null) state.checked = aria;
          else if (el.tagName.toLowerCase() === "input" && typeof el.checked === "boolean") state.checked = el.checked;
        }

        if (role === "option") {
          const aria = ariaBool(el, "aria-selected");
          state.selected = aria !== null ? aria : el.selected === true;
        } else {
          const aria = ariaBool(el, "aria-selected");
          if (aria !== null) state.selected = aria;
        }

        const expanded = ariaBool(el, "aria-expanded");
        if (expanded !== null) state.expanded = expanded;

        state.required = el.hasAttribute("required") || ariaBool(el, "aria-required") === true;
        state.readonly = el.hasAttribute("readonly") || ariaBool(el, "aria-readonly") === true;
        state.invalid = ariaBool(el, "aria-invalid") === true;
        state.focused = document.activeElement === el;

        if (role === "heading") {
          const level = parseInt(el.getAttribute("aria-level") || "", 10);
          state.level = isNaN(level) ? (parseInt(el.tagName.slice(1), 10) || null) : level;
        }
        return state;
      };

      // ---------------------------------------------------------------------
      // 遍历
      // ---------------------------------------------------------------------
      const nodes = [];
      const elements = [];

      const ensureRef = (el) => {
        let ref = el.getAttribute(REF_ATTR);
        if (ref) return ref;
        STATE.counter += 1;
        ref = "lumi-" + STATE.counter;
        try { el.setAttribute(REF_ATTR, ref); } catch (_) {}
        return ref;
      };

      // role 为 null 表示「无语义的容器」：自身不进树，但必须继续遍历子树，
      // 否则一个普通 <div> 包裹层会让整棵子树消失。
      const visit = (el, parentIndex, depth) => {
        if (nodes.length >= MAX_NODES || depth > MAX_DEPTH) return;
        if (isHidden(el)) return;

        const role = roleOf(el);
        let index = parentIndex;

        if (role !== null && !SKIP_ROLES.has(role)) {
          const node = {
            ref: ensureRef(el),
            role: role,
            name: accessibleName(el),
            parent: parentIndex,
            value: valueOf(el),
            href: hrefOf(el)
          };
          const state = stateOf(el, role);
          for (const key in state) node[key] = state[key];
          nodes.push(node);
          elements.push(el);
          index = nodes.length - 1;
        }

        const children = el.children || [];
        for (let i = 0; i < children.length; i++) {
          visit(children[i], index, depth + 1);
        }

        if (el.shadowRoot) {
          const shadowChildren = el.shadowRoot.children || [];
          for (let i = 0; i < shadowChildren.length; i++) {
            visit(shadowChildren[i], index, depth + 1);
          }
        }
      };

      const root = document.body || document.documentElement;
      if (root) visit(root, -1, 0);

      // ---------------------------------------------------------------------
      // 操作
      // ---------------------------------------------------------------------
      if (OPTS.op === "find") {
        const wantRole = (OPTS.role || "").toLowerCase();
        const wantName = (OPTS.name || "").toLowerCase();
        const wantText = (OPTS.text || "").toLowerCase();
        const limit = OPTS.limit || 20;

        const matches = [];
        for (let i = 0; i < nodes.length && matches.length < limit; i++) {
          const node = nodes[i];
          if (wantRole && node.role !== wantRole) continue;
          if (wantName) {
            const name = (node.name || "").toLowerCase();
            if (name !== wantName && name.indexOf(wantName) === -1) continue;
          }
          if (wantText) {
            // 文本匹配看元素的可见文本，而不只是可访问名：
            // 「点这个登录按钮」常常指的是按钮里的文字，而非它的 aria-label。
            const haystack = ((node.name || "") + " " + (elements[i].innerText || "")).toLowerCase();
            if (haystack.indexOf(wantText) === -1) continue;
          }
          matches.push(node);
        }
        return { matches: matches, total: nodes.length };
      }

      return { nodes: nodes, total: nodes.length };
    })()
    """#
}
