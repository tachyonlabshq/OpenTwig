import { InputHTMLAttributes, forwardRef } from 'react';

interface Props extends InputHTMLAttributes<HTMLInputElement> {
  label: string;
  caption?: string;
}

const Field = forwardRef<HTMLInputElement, Props>(({ label, caption, className = '', ...rest }, ref) => {
  return (
    <div className="w-full">
      <label className="block uppercase tracking-widest text-[var(--color-fg-tertiary)] font-mono text-[10px] mb-2">
        {label}
      </label>
      <input
        ref={ref}
        {...rest}
        className={`w-full font-mono text-base text-[var(--color-fg)] py-2 border-b border-[var(--color-border)] focus:border-[var(--color-accent)] transition-colors ${className}`}
      />
      {caption && (
        <p className="mt-2 text-xs text-[var(--color-fg-tertiary)] font-sans">{caption}</p>
      )}
    </div>
  );
});

Field.displayName = 'Field';
export default Field;
