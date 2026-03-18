import { test, expect } from '@playwright/test';

test('has title', async ({ page }) => {
  await page.goto('/');
  await expect(page).toHaveTitle(/OKernel/);
});

test('navigation to cpu scheduler', async ({ page }) => {
  await page.goto('/');
  // Match "Launch CPU Scheduler" button
  await page.click('text=Launch CPU Scheduler');
  await expect(page).toHaveURL(/\/cpu-scheduler/);
});

test('navigation to architecture', async ({ page }) => {
  await page.goto('/');
  await page.click('text=Architecture');
  await expect(page).toHaveURL(/\/architecture/);
});
