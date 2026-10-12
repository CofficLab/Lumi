import Foundation

enum HTMLPreviewElementBridgeScript {
    static let messageHandlerName = "lumiElementContextMenu"
    static let source = makeSource(navigationGeneration: 0)

    static func makeSource(navigationGeneration: Int) -> String {
        #"""
        (function () {
            if (window.__lumiElementBridge && window.__lumiElementBridge.dispose) {
                window.__lumiElementBridge.dispose();
            }

            var navigationGeneration = \#(navigationGeneration);
            var overlayHost = null;
            var outline = null;
            var highlightedElement = null;
            var requestCounter = 0;
            var maximumOuterHTMLBytes = 24 * 1024;
            var allowedAttributes = [
                'id', 'class', 'role', 'aria-label', 'name', 'type', 'alt', 'title',
                'data-block', 'data-block-label', 'data-prototype-link', 'data-prototype-label'
            ];
            var structuralTags = new Set(['li', 'article', 'section', 'header', 'main', 'nav', 'footer']);
            var decorativeTags = new Set(['span', 'svg', 'path', 'use']);

            function utf8Length(value) {
                if (window.TextEncoder) { return new TextEncoder().encode(value).length; }
                return unescape(encodeURIComponent(value)).length;
            }

            function truncateUTF8(value, maximumBytes) {
                if (utf8Length(value) <= maximumBytes) {
                    return { value: value, truncated: false };
                }
                var low = 0;
                var high = value.length;
                while (low < high) {
                    var midpoint = Math.ceil((low + high) / 2);
                    if (utf8Length(value.slice(0, midpoint)) <= maximumBytes) {
                        low = midpoint;
                    } else {
                        high = midpoint - 1;
                    }
                }
                var bounded = value.slice(0, low);
                if (bounded.length && /[\uD800-\uDBFF]/.test(bounded.charAt(bounded.length - 1))) {
                    bounded = bounded.slice(0, -1);
                }
                return { value: bounded, truncated: true };
            }

            function normalizedText(value, maximumCharacters) {
                return String(value || '')
                    .replace(/[\u0000-\u001F\u007F]+/g, ' ')
                    .replace(/\s+/g, ' ')
                    .trim()
                    .slice(0, maximumCharacters);
            }

            function isVisible(element) {
                if (!element || !(element instanceof Element)) { return false; }
                var style = window.getComputedStyle(element);
                if (style.display === 'none' || style.visibility === 'hidden') { return false; }
                var rect = element.getBoundingClientRect();
                return rect.width > 0 && rect.height > 0;
            }

            function isBridgeElement(element) {
                return !!(overlayHost && (element === overlayHost || overlayHost.contains(element)));
            }

            function hasMeaning(element) {
                if (!element || !isVisible(element)) { return false; }
                if (element.hasAttribute('data-block') || element.hasAttribute('aria-label') || element.hasAttribute('role')) {
                    return true;
                }
                if (normalizedText(element.textContent, 256)) { return true; }
                var rect = element.getBoundingClientRect();
                return rect.width > 16 && rect.height > 16;
            }

            function normalizedTarget(target) {
                if (!target || !(target instanceof Element) || isBridgeElement(target)) { return null; }
                var interactive = target.closest('button, a, input, select, textarea, [role], [data-prototype-link]');
                if (interactive && interactive !== document.body && isVisible(interactive)) { return interactive; }
                var current = target;
                if (decorativeTags.has(current.tagName.toLowerCase())) {
                    while (current && current !== document.body && !hasMeaning(current)) {
                        current = current.parentElement;
                    }
                }
                return current && current !== document.body && isVisible(current) ? current : null;
            }

            function cssEscape(value) {
                if (window.CSS && window.CSS.escape) { return window.CSS.escape(value); }
                return String(value).replace(/[^a-zA-Z0-9_-]/g, function (character) {
                    return '\\' + character.codePointAt(0).toString(16) + ' ';
                });
            }

            function attributeValueEscape(value) {
                return String(value).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/[\r\n\f]/g, ' ');
            }

            function isUniqueSelector(selector) {
                try { return document.querySelectorAll(selector).length === 1; }
                catch (_) { return false; }
            }

            function nthSegment(element) {
                var tag = element.tagName.toLowerCase();
                var siblings = element.parentElement
                    ? Array.from(element.parentElement.children).filter(function (item) { return item.tagName === element.tagName; })
                    : [];
                if (siblings.length <= 1) { return tag; }
                return tag + ':nth-of-type(' + (siblings.indexOf(element) + 1) + ')';
            }

            function selectorFor(element) {
                var blockID = element.getAttribute('data-block');
                if (blockID) {
                    var blockSelector = '[data-block="' + attributeValueEscape(blockID) + '"]';
                    if (isUniqueSelector(blockSelector)) { return blockSelector; }
                }
                if (element.id) {
                    var idSelector = '#' + cssEscape(element.id);
                    if (isUniqueSelector(idSelector)) { return idSelector; }
                }

                var stableNames = ['role', 'name', 'type', 'aria-label', 'data-prototype-link'];
                for (var index = 0; index < stableNames.length; index += 1) {
                    var name = stableNames[index];
                    var value = element.getAttribute(name);
                    if (!value) { continue; }
                    var attributeSelector = element.tagName.toLowerCase() + '[' + name + '="' + attributeValueEscape(value) + '"]';
                    if (isUniqueSelector(attributeSelector)) { return attributeSelector; }
                }

                var segments = [];
                var current = element;
                while (current && current !== document.body) {
                    var currentBlockID = current.getAttribute('data-block');
                    if (currentBlockID) {
                        var currentBlockSelector = '[data-block="' + attributeValueEscape(currentBlockID) + '"]';
                        if (isUniqueSelector(currentBlockSelector)) {
                            segments.unshift(currentBlockSelector);
                            var anchored = segments.join(' > ');
                            if (isUniqueSelector(anchored)) { return anchored; }
                        }
                    }
                    if (current.id) {
                        var currentIDSelector = '#' + cssEscape(current.id);
                        if (isUniqueSelector(currentIDSelector)) {
                            segments.unshift(currentIDSelector);
                            var idAnchored = segments.join(' > ');
                            if (isUniqueSelector(idAnchored)) { return idAnchored; }
                        }
                    }
                    segments.unshift(nthSegment(current));
                    var candidate = segments.join(' > ');
                    if (isUniqueSelector(candidate)) { return candidate; }
                    current = current.parentElement;
                }
                var fullSelector = 'body > ' + segments.join(' > ');
                return isUniqueSelector(fullSelector) ? fullSelector : nthSegment(element);
            }

            function labelFor(element) {
                var label = element.getAttribute('data-block-label')
                    || element.getAttribute('aria-label')
                    || element.getAttribute('alt')
                    || element.getAttribute('title')
                    || element.getAttribute('data-block')
                    || normalizedText(element.textContent, 256)
                    || element.tagName.toLowerCase();
                return normalizedText(label, 256);
            }

            function attributesFor(element) {
                var attributes = {};
                allowedAttributes.forEach(function (name) {
                    if (element.hasAttribute(name)) {
                        attributes[name] = String(element.getAttribute(name)).slice(0, 1024);
                    }
                });
                return attributes;
            }

            function referenceFor(element) {
                var editingScope = element.closest('[data-block]');
                var html = truncateUTF8(element.outerHTML || '', maximumOuterHTMLBytes);
                return {
                    schemaVersion: 1,
                    selector: selectorFor(element),
                    tagName: element.tagName.toLowerCase(),
                    label: labelFor(element),
                    textPreview: normalizedText(element.textContent, 512) || null,
                    outerHTML: html.value,
                    isOuterHTMLTruncated: html.truncated,
                    blockID: editingScope ? normalizedText(editingScope.getAttribute('data-block'), 256) || null : null,
                    blockLabel: editingScope ? normalizedText(editingScope.getAttribute('data-block-label'), 256) || null : null,
                    attributes: attributesFor(element)
                };
            }

            function hasSameRect(lhs, rhs) {
                var a = lhs.getBoundingClientRect();
                var b = rhs.getBoundingClientRect();
                return Math.abs(a.left - b.left) < 0.5
                    && Math.abs(a.top - b.top) < 0.5
                    && Math.abs(a.width - b.width) < 0.5
                    && Math.abs(a.height - b.height) < 0.5;
            }

            function inspect(target) {
                var selected = normalizedTarget(target);
                if (!selected) { return []; }
                var elements = [selected];
                var parent = selected.parentElement;
                var genericParentAdded = false;
                while (parent && parent !== document.body && elements.length < 5) {
                    var tag = parent.tagName.toLowerCase();
                    var explicitlyMeaningful = parent.hasAttribute('data-block')
                        || parent.hasAttribute('role')
                        || structuralTags.has(tag);
                    var genericallyMeaningful = !genericParentAdded
                        && (parent.hasAttribute('aria-label') || parent.hasAttribute('data-block-label'));
                    if (isVisible(parent)
                        && (explicitlyMeaningful || genericallyMeaningful)
                        && !hasSameRect(elements[elements.length - 1], parent)) {
                        elements.push(parent);
                        if (!explicitlyMeaningful) { genericParentAdded = true; }
                    }
                    parent = parent.parentElement;
                }

                var references = [];
                var selectors = new Set();
                elements.forEach(function (element) {
                    var reference = referenceFor(element);
                    if (!selectors.has(reference.selector)) {
                        selectors.add(reference.selector);
                        references.push(reference);
                    }
                });
                return references;
            }

            function ensureOverlay() {
                if (overlayHost && overlayHost.isConnected) { return; }
                overlayHost = document.createElement('div');
                overlayHost.setAttribute('data-lumi-element-overlay', '');
                overlayHost.style.position = 'fixed';
                overlayHost.style.inset = '0';
                overlayHost.style.pointerEvents = 'none';
                overlayHost.style.zIndex = '2147483647';
                var shadow = overlayHost.attachShadow({ mode: 'open' });
                outline = document.createElement('div');
                outline.style.position = 'fixed';
                outline.style.pointerEvents = 'none';
                outline.style.border = '2px solid rgba(91,92,226,.98)';
                outline.style.borderRadius = '6px';
                outline.style.boxShadow = '0 0 0 3px rgba(91,92,226,.18)';
                outline.style.boxSizing = 'border-box';
                shadow.appendChild(outline);
                document.documentElement.appendChild(overlayHost);
            }

            function updateHighlight() {
                if (!highlightedElement || !outline || !highlightedElement.isConnected) { return; }
                var rect = highlightedElement.getBoundingClientRect();
                outline.style.left = rect.left + 'px';
                outline.style.top = rect.top + 'px';
                outline.style.width = rect.width + 'px';
                outline.style.height = rect.height + 'px';
            }

            function highlight(element) {
                var selected = normalizedTarget(element);
                if (!selected) { clear(); return; }
                highlightedElement = selected;
                ensureOverlay();
                updateHighlight();
            }

            function clear() {
                highlightedElement = null;
                if (overlayHost) { overlayHost.remove(); }
                overlayHost = null;
                outline = null;
            }

            function onContextMenu(event) {
                var target = normalizedTarget(event.target);
                var candidates = inspect(target);
                if (!target || candidates.length === 0) { return; }
                event.preventDefault();
                event.stopPropagation();
                highlight(target);
                requestCounter += 1;
                var payload = {
                    schemaVersion: 1,
                    action: 'openContextMenu',
                    requestID: String(navigationGeneration) + '-' + String(requestCounter),
                    navigationGeneration: navigationGeneration,
                    clientX: event.clientX,
                    clientY: event.clientY,
                    candidates: candidates
                };
                while (utf8Length(JSON.stringify(payload)) > 128 * 1024 && payload.candidates.length > 1) {
                    payload.candidates.pop();
                }
                try {
                    window.webkit.messageHandlers.lumiElementContextMenu.postMessage(payload);
                } catch (_) {
                    clear();
                }
            }

            function onKeyDown(event) {
                if (event.key === 'Escape') { clear(); }
            }

            function dispose() {
                document.removeEventListener('contextmenu', onContextMenu, true);
                document.removeEventListener('keydown', onKeyDown, true);
                window.removeEventListener('scroll', updateHighlight, true);
                window.removeEventListener('resize', updateHighlight, true);
                clear();
                if (window.__lumiElementBridge === api) {
                    delete window.__lumiElementBridge;
                }
            }

            document.addEventListener('contextmenu', onContextMenu, true);
            document.addEventListener('keydown', onKeyDown, true);
            window.addEventListener('scroll', updateHighlight, true);
            window.addEventListener('resize', updateHighlight, true);

            var api = {
                inspect: inspect,
                highlight: highlight,
                clear: clear,
                dispose: dispose
            };
            window.__lumiElementBridge = api;
        })();
        """#
    }
}
