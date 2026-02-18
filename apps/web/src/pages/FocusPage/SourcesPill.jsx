import { useState } from 'react';
import styles from './FocusChatWindow.module.css';

export default function SourcesPill({ sources }) {
  const [open, setOpen] = useState(false);

  if (!sources || sources.length === 0) return null;

  return (
    <div className={styles.sourcesPill}>
      <button
        className={styles.sourcesToggle}
        onClick={() => setOpen((v) => !v)}
        aria-expanded={open}
      >
        {sources.length} {sources.length === 1 ? 'source' : 'sources'}
        <span className={styles.sourcesChevron} aria-hidden>{open ? '\u25B4' : '\u25BE'}</span>
      </button>
      {open && (
        <ul className={styles.sourcesList}>
          {sources.map((s, i) => (
            <li key={i}>
              <a href={s.url} target="_blank" rel="noopener noreferrer">
                {s.title}
              </a>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
