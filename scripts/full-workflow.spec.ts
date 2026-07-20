import { expect, test } from '@playwright/test';

async function enableSemantics(page: import('@playwright/test').Page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 15_000 });
  await placeholder.evaluate((element: HTMLElement) => element.click());
  await page.locator('flt-semantics').first().waitFor({ state: 'attached' });
}

test('synthetic educational profile workflow', async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 });
  await page.goto('/');
  await enableSemantics(page);

  await expect(page.getByText('Synthetic data only.', { exact: false })).toBeVisible();
  await page.getByRole('button', { name: 'Load synthetic example' }).click();
  await page.getByRole('button', { name: 'Generate educational profile' }).click();

  await expect(page.getByRole('group', { name: 'Educational Scorecard' })).toBeVisible();
  await expect(page.getByText('Educational profile score', { exact: false }).first()).toBeVisible();
  await expect(page.getByText('unvalidated heuristic', { exact: false }).first()).toBeVisible();

  await page.getByRole('button', { name: /What-If Tab/ }).click();
  await expect(page.getByText('What-If Simulator', { exact: true })).toBeVisible();
  const exerciseSlider = page.getByRole('slider').nth(2);
  const sliderBox = await exerciseSlider.boundingBox();
  expect(sliderBox).not.toBeNull();
  await page.mouse.click(
    sliderBox!.x + sliderBox!.width * 0.8,
    sliderBox!.y + sliderBox!.height / 2,
  );
  await expect(exerciseSlider).not.toHaveAttribute('aria-valuenow', '50');
  const runWhatIfButton = page.getByRole('button', { name: 'Run What-If' });
  await runWhatIfButton.focus();
  await runWhatIfButton.press('Enter');
  await expect(page.getByText('Score delta:', { exact: false })).toBeVisible();

  await page.getByRole('button', { name: /History Tab/ }).click();
  await expect(page.getByText('Educational Score History', { exact: true })).toBeVisible();
  await expect(page.getByText('band (', { exact: false }).first()).toBeVisible();

  await page.getByRole('button', { name: /Assistant Tab/ }).click();
  await expect(page.getByText('not medical advice', { exact: false }).first()).toBeVisible();
});

test('mobile shell has no horizontal overflow', async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await enableSemantics(page);

  const metrics = await page.evaluate(() => ({
    viewport: window.innerWidth,
    documentWidth: document.documentElement.scrollWidth,
  }));
  expect(metrics.documentWidth).toBeLessThanOrEqual(metrics.viewport);
  await expect(page.getByRole('button', { name: 'Load synthetic example' })).toBeVisible();
});
