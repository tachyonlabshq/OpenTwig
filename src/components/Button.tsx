import { ButtonHTMLAttributes, ReactNode } from 'react';

type Variant = 'primary' | 'secondary' | 'plain';

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  children: ReactNode;
}

export default function Button({ variant = 'plain', children, className = '', disabled, ...rest }: Props) {
  const base = 'transition-colors duration-150 disabled:opacity-30 disabled:cursor-not-allowed';
  const styles: Record<Variant, string> = {
    primary: 'text-[var(--color-accent)] font-mono text-sm tracking-wide hover:opacity-70',
    secondary: 'text-[var(--color-fg-secondary)] font-mono text-sm tracking-wide hover:text-[var(--color-fg)]',
    plain: 'text-[var(--color-fg)] font-mono text-sm tracking-wide hover:opacity-70',
  };
  return (
    <button {...rest} disabled={disabled} className={`${base} ${styles[variant]} ${className}`}>
      {children}
    </button>
  );
}
