/**
 * GrowthBook SDK integration for 37Design Marketing OS
 * Used for A/B testing and feature flags
 */

const GROWTHBOOK_API_HOST = 'https://growthbook.37d.jp';

/**
 * Initialize GrowthBook client-side
 * @param {string} clientKey - GrowthBook client key
 * @returns {Promise<import('@growthbook/growthbook').GrowthBook>}
 */
export async function initGrowthBook(clientKey) {
  const { GrowthBook } = await import('@growthbook/growthbook');

  const gb = new GrowthBook({
    apiHost: GROWTHBOOK_API_HOST,
    clientKey,
    enableDevMode: import.meta.env.DEV,
    trackingCallback: (experiment, result) => {
      // Send experiment exposure to GA4
      if (typeof gtag !== 'undefined') {
        gtag('event', 'experiment_viewed', {
          experiment_id: experiment.key,
          variation_id: result.key,
        });
      }
      console.log('Experiment viewed:', {
        experimentId: experiment.key,
        variationId: result.key,
      });
    },
  });

  await gb.init({ timeout: 3000 });
  return gb;
}

/**
 * Get feature value with fallback
 * @param {import('@growthbook/growthbook').GrowthBook} gb
 * @param {string} featureKey
 * @param {any} fallback
 * @returns {any}
 */
export function getFeatureValue(gb, featureKey, fallback) {
  return gb.getFeatureValue(featureKey, fallback);
}

/**
 * Check if feature is on
 * @param {import('@growthbook/growthbook').GrowthBook} gb
 * @param {string} featureKey
 * @returns {boolean}
 */
export function isFeatureOn(gb, featureKey) {
  return gb.isOn(featureKey);
}
