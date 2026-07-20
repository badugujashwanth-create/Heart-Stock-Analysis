import { expect, test } from '@playwright/test';

test.use({
  viewport: { width: 1280, height: 720 },
  video: { mode: 'on', size: { width: 1280, height: 720 } },
});

test.setTimeout(360_000);

const fast = process.env.DEMO_FAST === 'true';
const pause = (page: import('@playwright/test').Page, ms: number) =>
  page.waitForTimeout(fast ? Math.min(ms, 250) : ms);

async function enableSemantics(page: import('@playwright/test').Page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 15_000 });
  await placeholder.evaluate((element: HTMLElement) => element.click());
  await page.locator('flt-semantics').first().waitFor({ state: 'attached' });
}

test('HeartAnalysis narrated release walkthrough', async ({ page }) => {
  await page.goto('/');
  await enableSemantics(page);
  await expect(page.getByText('Synthetic data only.', { exact: false })).toBeVisible();
  await pause(page, 22_000);

  await page.getByRole('button', { name: 'Load synthetic example' }).click();
  await pause(page, 12_000);
  await page.mouse.move(920, 620, { steps: 20 });
  await page.mouse.wheel(0, 560);
  await pause(page, 12_000);
  await page.mouse.wheel(0, 620);
  await pause(page, 10_000);

  await page.getByRole('button', { name: 'Generate educational profile' }).click();
  await expect(page.getByRole('group', { name: 'Educational Scorecard' })).toBeVisible();
  await pause(page, 22_000);
  await page.mouse.move(980, 540, { steps: 20 });
  await page.mouse.wheel(0, 620);
  await pause(page, 18_000);
  await page.mouse.wheel(0, 680);
  await pause(page, 18_000);

  await page.getByRole('button', { name: /What-If Tab/ }).click();
  await expect(page.getByText('What-If Simulator', { exact: true })).toBeVisible();
  await pause(page, 15_000);
  const exerciseSlider = page.getByRole('slider').nth(2);
  const sliderBox = await exerciseSlider.boundingBox();
  expect(sliderBox).not.toBeNull();
  await page.mouse.click(
    sliderBox!.x + sliderBox!.width * 0.8,
    sliderBox!.y + sliderBox!.height / 2,
  );
  await pause(page, 10_000);
  await page.getByRole('button', { name: 'Run What-If' }).click();
  await expect(page.getByText('Score delta:', { exact: false })).toBeVisible();
  await pause(page, 22_000);

  await page.getByRole('button', { name: /History Tab/ }).click();
  await expect(page.getByText('Educational Score History', { exact: true })).toBeVisible();
  await expect(page.getByText('band (', { exact: false }).first()).toBeVisible();
  await pause(page, 22_000);

  await page.getByRole('button', { name: /Assistant Tab/ }).click();
  await expect(page.getByText('not medical advice', { exact: false }).first()).toBeVisible();
  await pause(page, 14_000);
  const prompt = page.getByRole('textbox', { name: /Ask assistant/i });
  await prompt.fill('What should this synthetic profile focus on this week?');
  await page.getByRole('button', { name: 'Send' }).click();
  await expect(page.getByText('Current educational profile:', { exact: false })).toBeVisible();
  await pause(page, 24_000);

  await page.getByRole('button', { name: /Report Tab/ }).click();
  await expect(page.getByRole('group', { name: 'Educational Scorecard' })).toBeVisible();
  await pause(page, 24_000);
});
