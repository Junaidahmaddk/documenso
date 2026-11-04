import { useLingui } from '@lingui/react/macro';
import { useEffect, useLayoutEffect, useRef } from 'react';

import { cn } from '../../lib/utils';

export type SignaturePadTypeProps = {
  className?: string;
  value?: string;
  defaultValue?: string;
  onChange: (_value: string) => void;
};

export const SignaturePadType = ({ className, value, defaultValue, onChange }: SignaturePadTypeProps) => {
  const { t } = useLingui();

  const $isDirty = useRef(false);
  const $input = useRef<HTMLInputElement>(null);
  // Colors don't actually work for text.

  useEffect(() => {
    if (!$isDirty.current && !value && defaultValue) {
      $isDirty.current = true;
      onChange(defaultValue);
    }
  }, [defaultValue, value, onChange]);

  // Fairhomes: skriften skrumper, til hele navnet kan ses i feltet (især på telefon, hvor text-7xl skjuler det meste af
  // et langt navn). Kun visningen ændres; underskriften gemmes som tekst og tegnes i feltet i sin egen størrelse.
  useLayoutEffect(() => {
    const el = $input.current;

    if (!el) {
      return;
    }

    const fit = () => {
      el.style.fontSize = '';

      if (!el.value) {
        return;
      }

      let size = parseFloat(getComputedStyle(el).fontSize);

      while (el.scrollWidth > el.clientWidth && size > 20) {
        size -= 2;
        el.style.fontSize = `${size}px`;
      }
    };

    fit();

    // Skriften (Caveat) kan blive færdig med at indlæse efter første måling; drejes telefonen, ændres bredden.
    void document.fonts?.ready.then(fit);
    window.addEventListener('resize', fit);

    return () => window.removeEventListener('resize', fit);
  }, [value]);

  return (
    <div className={cn('flex h-full w-full items-center justify-center', className)}>
      <input
        ref={$input}
        data-testid="signature-pad-type-input"
        placeholder={t`Type your signature`}
        // Fairhomes: mindre startskrift på telefon (se useLayoutEffect ovenfor).
        className="w-full bg-transparent px-4 text-center font-signature text-5xl text-foreground placeholder:text-3xl focus-visible:outline-none focus-visible:ring-0 focus-visible:ring-offset-0 sm:text-7xl sm:placeholder:text-4xl"
        // style={{ color: selectedColor }}
        value={value}
        onChange={(event) => {
          onChange(event.target.value.trimStart());
          $isDirty.current = true;
        }}
        autoComplete="off"
        autoCorrect="off"
        autoCapitalize="words"
        spellCheck={false}
      />

      {/* <SignaturePadColorPicker selectedColor={selectedColor} setSelectedColor={setSelectedColor} /> */}
    </div>
  );
};
