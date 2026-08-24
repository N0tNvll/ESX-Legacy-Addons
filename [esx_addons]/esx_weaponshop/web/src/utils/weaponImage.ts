const DOCS_IMAGE_PREFIX = 'https://docs-backend.fivem.net/weapons/';

/**
 * Builds the FiveM docs weapon image URL
 * @param weaponName - Weapon spawn name
 * @returns Image URL
 */
export function getDocsWeaponImage(weaponName: string): string {
  return `${DOCS_IMAGE_PREFIX}${weaponName}.png`;
}

/**
 * Probes whether an image URL can be loaded by the browser
 * @param url - Image URL
 */
function canLoadImage(url: string): Promise<boolean> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(true);
    img.onerror = () => resolve(false);
    img.src = url;
  });
}

/**
 * Resolves the best display URL for a weapon image
 * Prefers inventory images, otherwise falls back to FiveM docs images
 * @param weaponName - Weapon spawn name
 * @param image - Preferred image URL from Lua
 */
export async function resolveWeaponImage(weaponName: string, image: string): Promise<string | null> {
  const docsUrl = getDocsWeaponImage(weaponName);
  const primary = image || docsUrl;

  if (await canLoadImage(primary)) {
    return primary;
  }

  return primary !== docsUrl && await canLoadImage(docsUrl) ? docsUrl : null;
}
