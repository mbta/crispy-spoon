const fs = require('fs');
const path = require('path');
const { performance } = require('node:perf_hooks');

const { test, expect } = require('@playwright/test');

const filesPath = path.join(__dirname, '..', 'scenarios');
const files = fs.readdirSync(filesPath);

const baseURL = process.env.TARGET_URL;

files.forEach((file) => {
    test.describe('All scenarios', () => {
        const filePath = path.join(filesPath, file);
        const { scenario } = require(filePath);

        test(scenario.name, async ({ page }) => {
            const start = performance.now();

            await scenario.run({ page, baseURL });

            const end = performance.now();
            const duration = end - start;

            expect.soft(duration, 'Duration is below threshold').toBeLessThanOrEqual(scenario.threshold);
        });
    });
});
