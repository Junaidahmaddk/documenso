import type { SVGAttributes } from 'react';

export type LogoProps = SVGAttributes<SVGSVGElement>;

// Fairhomes: monogrammet (samme som app-ikonet, serveret af nginx) i stedet for Documensos ikon.
export const BrandingLogoIcon = ({ ...props }: LogoProps) => {
  return (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 84 84" role="img" aria-label="Fairhomes" {...props}>
      <image href="/apple-touch-icon.png" width="84" height="84" />
    </svg>
  );
};
