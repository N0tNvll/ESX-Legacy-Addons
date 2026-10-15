import type { Theme } from '../types/payment'

const hexColor = /^#[0-9a-f]{6}$/i

/** Adds a hex alpha suffix to a #rrggbb colour; any other format uses `fallback`. */
const withAlpha = (color: string, alpha: string, fallback: string) =>
  hexColor.test(color) ? `${color}${alpha}` : fallback

/** Maps the esx:ui:* convar values to the CSS variables used by style.css. Missing values keep the CSS defaults. */
export function applyTheme(theme: Partial<Theme>) {
  const style = document.documentElement.style
  const { primaryColor, secondaryColor, backgroundColor, accentColor } = theme

  if (primaryColor) {
    style.setProperty('--primary', primaryColor)
    style.setProperty('--primary-hover', withAlpha(primaryColor, '0f', 'transparent'))
    style.setProperty('--primary-selected', withAlpha(primaryColor, '17', 'transparent'))
  }

  if (secondaryColor) {
    style.setProperty('--secondary-glass', withAlpha(secondaryColor, '80', secondaryColor))
  }

  if (backgroundColor) {
    style.setProperty('--background', backgroundColor)
    style.setProperty('--background-glass', withAlpha(backgroundColor, 'f5', backgroundColor))
  }

  if (accentColor) style.setProperty('--accent', accentColor)
}
