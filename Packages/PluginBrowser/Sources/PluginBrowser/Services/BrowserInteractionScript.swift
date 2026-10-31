import Foundation

/// 页面内交互动作的执行脚本。
///
/// 所有动作共用一段脚本，靠 `__OPTS.action` 分派，理由有三：
///
/// 1. **ref 解析只有一份**。分散到各动作里就会出现「click 认识 ref、hover 不认识」
///    这类不一致，LLM 会因此误判某些 ref 不可用。
/// 2. **stale 诊断只有一份**。所有动作共享同一套「元素已消失」提示。
/// 3. **返回值结构统一**。统一返回 `{ ok, href, message, value }`，
///    Swift 侧不用为每个动作写一遍解包。
enum BrowserInteractionScript {
    /// 生成执行交互的脚本。
    ///
    /// - Parameters:
    ///   - action: 动作名。
    ///   - ref: 目标元素的 ref；整页滚动时传 nil。
    ///   - text: 文本类动作的载荷。
    static func script(action: BrowserInteractionAction, ref: String?, text: String?) -> String {
        var options: [String: Any] = ["action": action.rawValue]
        if let ref { options["ref"] = ref }
        if let text { options["text"] = text }

        guard let data = try? JSONSerialization.data(withJSONObject: options),
              let json = String(data: data, encoding: .utf8) else {
            return "({ ok: false, message: 'invalid request' })"
        }
        return "const __OPTS = \(json);\n" + body
    }

    private static let body = #"""
    (() => {
      const OPTS = __OPTS;
      const REF_ATTR = "data-lumi-browser-ref";

      const fail = (message) => ({ ok: false, message: message });

      // 整页滚动不需要元素。
      if (OPTS.action === "scroll") {
        const direction = String(OPTS.text || "down").toLowerCase();
        const amount = 400;
        const vertical = direction === "up" ? -amount
          : direction === "down" ? amount
          : direction === "top" ? -1000000
          : direction === "bottom" ? 1000000
          : 0;
        const horizontal = direction === "left" ? -amount : direction === "right" ? amount : 0;
        if (vertical === 0 && horizontal === 0) {
          return fail("Unknown scroll direction. Use up, down, left, right, top, or bottom.");
        }
        window.scrollBy({ top: vertical, left: horizontal, behavior: "instant" });
        return { ok: true, message: "Scrolled " + direction + "." };
      }

      const ref = OPTS.ref;
      if (!ref) return fail("Missing element reference.");

      const el = document.querySelector("[" + REF_ATTR + '="' + ref + '"]');
      if (!el) {
        return fail("STALE_REF:" + ref);
      }

      // 元素必须可见且可交互，否则点击会静默失败。
      const rect = el.getBoundingClientRect();
      const visible = rect.width > 0 && rect.height > 0 &&
        getComputedStyle(el).visibility !== "hidden" && getComputedStyle(el).display !== "none";
      if (!visible) {
        return fail("The element is not visible on the page.");
      }

      const disabled = el.hasAttribute("disabled") || el.getAttribute("aria-disabled") === "true";
      if (disabled && OPTS.action !== "hover") {
        return fail("The element is disabled.");
      }

      const focus = () => { try { el.focus({ preventScroll: true }); } catch (_) {} };

      const setValue = (value) => {
        const proto = el instanceof HTMLTextAreaElement
          ? HTMLTextAreaElement.prototype
          : HTMLInputElement.prototype;
        const setter = Object.getOwnPropertyDescriptor(proto, "value")?.set;
        if (!setter) return false;
        setter.call(el, value);
        el.dispatchEvent(new Event("input", { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
        return true;
      };

      const click = () => {
        // 用真实坐标点击，触发指针事件；元素被遮挡时点击会落到别的元素上。
        el.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
        const box = el.getBoundingClientRect();
        const x = box.left + box.width / 2;
        const y = box.top + box.height / 2;
        const target = document.elementFromPoint(x, y);
        if (target && !el.contains(target) && target !== el) {
          return fail("The element is covered by another element: " + (target.tagName || "unknown") + ".");
        }
        for (const type of ["pointerdown", "mousedown", "pointerup", "mouseup"]) {
          el.dispatchEvent(new MouseEvent(type, { bubbles: true, cancelable: true, clientX: x, clientY: y }));
        }
        el.click();
        return true;
      };

      switch (OPTS.action) {
        case "click": {
          if (el.tagName === "A" && el.getAttribute("href")) {
            return { ok: true, href: el.href, message: "Clicked link." };
          }
          if (!click()) return fail("The element could not be clicked.");
          return { ok: true, href: "", message: "Clicked." };
        }

        case "dblclick": {
          el.scrollIntoView({ block: "center", inline: "center", behavior: "instant" });
          el.dispatchEvent(new MouseEvent("dblclick", { bubbles: true, cancelable: true }));
          return { ok: true, href: "", message: "Double-clicked." };
        }

        case "fill": {
          if (!(el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement)) {
            return fail("This element does not accept text. Use select or click instead.");
          }
          const type = (el.getAttribute("type") || "").toLowerCase();
          if (["file", "hidden"].includes(type)) {
            return fail("This input cannot be filled with text.");
          }
          focus();
          if (!setValue(String(OPTS.text || ""))) {
            return fail("This element cannot be edited.");
          }
          return { ok: true, href: "", message: "Filled." };
        }

        case "type": {
          if (!(el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement)) {
            return fail("This element does not accept text.");
          }
          focus();
          // 逐字符输入并触发按键事件，贴近真实用户输入；
          // 与 fill 的差别是 fill 直接赋值、不触发按键。
          const value = String(OPTS.text || "");
          for (let i = 0; i < value.length; i++) {
            el.dispatchEvent(new KeyboardEvent("keydown", { key: value[i], bubbles: true }));
            el.dispatchEvent(new KeyboardEvent("keypress", { key: value[i], bubbles: true }));
            el.value = el.value + value[i];
            el.dispatchEvent(new KeyboardEvent("keyup", { key: value[i], bubbles: true }));
            el.dispatchEvent(new Event("input", { bubbles: true }));
          }
          el.dispatchEvent(new Event("change", { bubbles: true }));
          return { ok: true, href: "", message: "Typed." };
        }

        case "select": {
          if (!(el instanceof HTMLSelectElement)) {
            return fail("This element is not a select.");
          }
          const wanted = String(OPTS.text || "");
          const options = Array.from(el.options || []);
          const match = options.find((o) => o.value === wanted)
            || options.find((o) => (o.textContent || "").trim() === wanted)
            || options.find((o) => (o.textContent || "").trim().toLowerCase() === wanted.toLowerCase());
          if (!match) {
            const available = options.map((o) => (o.textContent || "").trim()).filter(Boolean).slice(0, 20).join(", ");
            return fail("No option matching \"" + wanted + "\". Available options: " + (available || "(none)") + ".");
          }
          el.value = match.value;
          el.dispatchEvent(new Event("input", { bubbles: true }));
          el.dispatchEvent(new Event("change", { bubbles: true }));
          return { ok: true, href: "", message: "Selected \"" + (match.textContent || "").trim() + "\"." };
        }

        case "check":
        case "uncheck": {
          const shouldCheck = OPTS.action === "check";
          const isCheckbox = el instanceof HTMLInputElement && el.type === "checkbox";
          const ariaChecked = el.getAttribute("aria-checked");
          if (isCheckbox) {
            if (el.checked !== shouldCheck) {
              el.checked = shouldCheck;
              el.dispatchEvent(new Event("input", { bubbles: true }));
              el.dispatchEvent(new Event("change", { bubbles: true }));
            }
          } else if (ariaChecked !== null) {
            if ((ariaChecked === "true") !== shouldCheck) {
              el.setAttribute("aria-checked", shouldCheck ? "true" : "false");
              el.dispatchEvent(new Event("change", { bubbles: true }));
            }
          } else {
            return fail("This element is not a checkbox.");
          }
          return { ok: true, href: "", message: shouldCheck ? "Checked." : "Unchecked." };
        }

        case "press": {
          const key = String(OPTS.text || "").trim();
          if (!key) return fail("Missing key name.");
          focus();
          const init = { key: key, bubbles: true, cancelable: true };
          el.dispatchEvent(new KeyboardEvent("keydown", init));
          el.dispatchEvent(new KeyboardEvent("keyup", init));
          if (key === "Enter") {
            // Enter 在表单里通常意味着提交。
            const form = el.form || el.closest("form");
            if (form) {
              form.dispatchEvent(new Event("submit", { bubbles: true, cancelable: true }));
              if (typeof form.requestSubmit === "function") {
                try { form.requestSubmit(); } catch (_) {}
              }
            }
          }
          return { ok: true, href: "", message: "Pressed " + key + "." };
        }

        case "hover": {
          el.dispatchEvent(new MouseEvent("mouseover", { bubbles: true }));
          el.dispatchEvent(new MouseEvent("mouseenter", { bubbles: true }));
          el.dispatchEvent(new MouseEvent("mousemove", { bubbles: true }));
          return { ok: true, href: "", message: "Hovered." };
        }

        case "focus": {
          focus();
          return { ok: true, href: "", message: "Focused." };
        }

        default:
          return fail("Unsupported action: " + OPTS.action);
      }
    })()
    """#
}
