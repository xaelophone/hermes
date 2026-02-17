import { useRef, useState } from 'react';
import { Extension } from '@tiptap/core';
import { Plugin, PluginKey } from '@tiptap/pm/state';
import { TextSelection } from '@tiptap/pm/state';
import { Decoration, DecorationSet } from '@tiptap/pm/view';

const LINK_PATTERN = /\[([^\]]*)\]\(([^)]*)\)/g;

function findLinkPatternAtCursor(state) {
  const { $head } = state.selection;
  const blockStart = $head.start();
  const blockText = $head.parent.textContent;
  const cursorInBlock = $head.pos - blockStart;

  let match;
  LINK_PATTERN.lastIndex = 0;
  while ((match = LINK_PATTERN.exec(blockText)) !== null) {
    const matchStart = match.index;
    const matchEnd = match.index + match[0].length;
    if (cursorInBlock >= matchStart && cursorInBlock <= matchEnd) {
      return {
        fullMatch: match[0],
        text: match[1],
        url: match[2],
        from: blockStart + matchStart,
        to: blockStart + matchEnd,
        // Position of the opening paren for URL
        parenOpen: blockStart + matchStart + match[1].length + 2,
        parenClose: blockStart + matchEnd - 1,
      };
    }
  }
  return null;
}

function findAllLinkPatterns(doc) {
  const results = [];
  doc.descendants((node, pos) => {
    if (!node.isTextblock) return;
    const text = node.textContent;
    const blockStart = pos + 1; // +1 to skip the node open token
    let match;
    LINK_PATTERN.lastIndex = 0;
    while ((match = LINK_PATTERN.exec(text)) !== null) {
      results.push({
        fullMatch: match[0],
        text: match[1],
        url: match[2],
        from: blockStart + match.index,
        to: blockStart + match.index + match[0].length,
      });
    }
  });
  return results;
}

function convertPatternToLink(tr, pattern, schema) {
  const { text, url, from, to } = pattern;
  const trimmedUrl = url.trim();

  if (trimmedUrl) {
    // Replace pattern text with just the display text, then add link mark
    tr.insertText(text, from, to);
    const linkMark = schema.marks.link.create({ href: trimmedUrl });
    tr.addMark(from, from + text.length, linkMark);
  } else {
    // Empty URL — just leave the plain text
    tr.insertText(text, from, to);
  }
  tr.setMeta('preventAutolink', true);
}

function createInlineLinkExtension(linkZoneRef) {
  const pluginKey = new PluginKey('inlineLink');

  return Extension.create({
    name: 'inlineLink',

    addKeyboardShortcuts() {
      return {
        'Mod-k': ({ editor: ed }) => {
          // If cursor is on an existing rendered link, toggle it off
          if (ed.isActive('link')) {
            ed.chain().focus().unsetLink().run();
            return true;
          }

          const { state } = ed;
          const { from, to, empty } = state.selection;

          const selectedText = empty ? '' : state.doc.textBetween(from, to);
          const insertStr = `[${selectedText}]()`;

          // Calculate cursor position: between the parens
          // [text]( | ) — cursor goes right after the opening paren
          const cursorPos = from + selectedText.length + 3; // [ + text + ] + ( = length + 3

          const tr = state.tr;
          tr.insertText(insertStr, from, to);
          tr.setSelection(TextSelection.create(tr.doc, cursorPos));
          tr.setMeta('preventAutolink', true);
          ed.view.dispatch(tr);

          linkZoneRef.current = true;
          return true;
        },

        Enter: ({ editor: ed }) => {
          if (!linkZoneRef.current) return false;

          const pattern = findLinkPatternAtCursor(ed.state);
          if (!pattern) return false;

          const { tr } = ed.state;
          convertPatternToLink(tr, pattern, ed.state.schema);

          // Place cursor at end of the converted text
          const newCursorPos = pattern.from + pattern.text.length;
          tr.setSelection(TextSelection.create(tr.doc, newCursorPos));
          ed.view.dispatch(tr);

          linkZoneRef.current = false;
          return true;
        },

        Escape: ({ editor: ed }) => {
          if (!linkZoneRef.current) return false;

          const pattern = findLinkPatternAtCursor(ed.state);
          if (!pattern) {
            // No pattern found but zone was active — just deactivate
            linkZoneRef.current = false;
            return true;
          }

          // Strip syntax, leave just the display text
          const { tr } = ed.state;
          tr.insertText(pattern.text, pattern.from, pattern.to);
          tr.setMeta('preventAutolink', true);

          const newCursorPos = pattern.from + pattern.text.length;
          tr.setSelection(TextSelection.create(tr.doc, newCursorPos));
          ed.view.dispatch(tr);

          linkZoneRef.current = false;
          return true;
        },
      };
    },

    addProseMirrorPlugins() {
      return [
        new Plugin({
          key: pluginKey,

          appendTransaction(transactions, _oldState, newState) {
            if (!linkZoneRef.current) return null;

            // Don't interfere if the transaction was from our own conversion
            const hasPreventAutolink = transactions.some(
              (t) => t.getMeta('preventAutolink'),
            );
            if (hasPreventAutolink) return null;

            const patterns = findAllLinkPatterns(newState.doc);
            if (patterns.length === 0) {
              // No patterns exist anymore (user deleted them) — deactivate
              linkZoneRef.current = false;
              return null;
            }

            const cursorPos = newState.selection.$head.pos;
            const cursorInPattern = patterns.some(
              (p) => cursorPos >= p.from && cursorPos <= p.to,
            );

            if (cursorInPattern) return null;

            // Cursor left the pattern — convert all found patterns
            const tr = newState.tr;
            // Process in reverse order so positions stay valid
            const sorted = [...patterns].sort((a, b) => b.from - a.from);
            for (const pattern of sorted) {
              convertPatternToLink(tr, pattern, newState.schema);
            }

            linkZoneRef.current = false;
            return tr;
          },

          state: {
            init() {
              return DecorationSet.empty;
            },
            apply(tr, oldSet, _oldState, newState) {
              if (!linkZoneRef.current) return DecorationSet.empty;

              const patterns = findAllLinkPatterns(newState.doc);
              if (patterns.length === 0) return DecorationSet.empty;

              const cursorPos = newState.selection.$head.pos;
              const decorations = [];

              for (const p of patterns) {
                if (cursorPos >= p.from && cursorPos <= p.to) {
                  decorations.push(
                    Decoration.inline(p.from, p.to, {
                      class: 'inline-link-editing',
                    }),
                  );
                }
              }

              if (decorations.length === 0) return DecorationSet.empty;
              return DecorationSet.create(newState.doc, decorations);
            },
          },

          props: {
            decorations(state) {
              return pluginKey.getState(state);
            },
          },
        }),
      ];
    },
  });
}

export default function useInlineLink() {
  const linkZoneRef = useRef(false);
  // linkZoneRef is captured by the ProseMirror plugin closure, not read during render
  // eslint-disable-next-line react-hooks/refs
  const [inlineLinkExtension] = useState(() =>
    createInlineLinkExtension(linkZoneRef),
  );

  return { inlineLinkExtension };
}
