const { test, expect } = require('@playwright/test');

// Test configuration
const BASE_URL = 'http://localhost:3000';
const TRANSCODER_URL = 'http://localhost:8083';
const STREAMS = ['stream1', 'stream2', 'stream3'];

test.describe('Enhanced Live Player Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the live player
    await page.goto(`${BASE_URL}/live-player.html`);
    
    // Wait for page to load
    await page.waitForLoadState('networkidle');
  });

  test('should load the live player interface', async ({ page }) => {
    // Check main elements are present
    await expect(page.locator('h1')).toContainText('StreamForge Enhanced Live Player');
    await expect(page.locator('.stream-list')).toBeVisible();
    await expect(page.locator('.log-panel')).toBeVisible();
  });

  test('should display available streams', async ({ page }) => {
    // Check stream list
    const streamItems = page.locator('.stream-item');
    await expect(streamItems).toHaveCount(3);
    
    // Verify stream names
    for (const stream of STREAMS) {
      await expect(page.locator(`[data-stream="${stream}"]`)).toBeVisible();
    }
  });

  test('should start a stream when clicked', async ({ page }) => {
    // Click on stream1
    await page.click('[data-stream="stream1"]');
    
    // Wait for player to be created
    await page.waitForSelector('#player-stream1', { timeout: 5000 });
    
    // Check player elements
    await expect(page.locator('#video-stream1')).toBeVisible();
    await expect(page.locator('.live-badge')).toBeVisible();
    await expect(page.locator('#quality-stream1')).toBeVisible();
    
    // Check stream is marked as active
    await expect(page.locator('[data-stream="stream1"]')).toHaveClass(/active/);
  });

  test('should handle multiple concurrent streams', async ({ page }) => {
    // Start multiple streams
    await page.click('[data-stream="stream1"]');
    await page.waitForSelector('#player-stream1');
    
    await page.click('[data-stream="stream2"]');
    await page.waitForSelector('#player-stream2');
    
    await page.click('[data-stream="stream3"]');
    await page.waitForSelector('#player-stream3');
    
    // Verify all players are present
    await expect(page.locator('#player-stream1')).toBeVisible();
    await expect(page.locator('#player-stream2')).toBeVisible();
    await expect(page.locator('#player-stream3')).toBeVisible();
    
    // Check no buffering indicators after 5 seconds
    await page.waitForTimeout(5000);
    const loadingSpinners = page.locator('.loading-spinner:visible');
    await expect(loadingSpinners).toHaveCount(0);
  });

  test('should switch quality levels', async ({ page }) => {
    // Start a stream
    await page.click('[data-stream="stream1"]');
    await page.waitForSelector('#player-stream1');
    
    // Wait for quality options to load
    await page.waitForTimeout(3000);
    
    // Click quality selector
    await page.click('#quality-stream1');
    
    // Wait for dropdown
    await expect(page.locator('#quality-dropdown-stream1')).toBeVisible();
    
    // Check quality options are present
    const qualityOptions = page.locator('#quality-dropdown-stream1 .quality-option');
    await expect(qualityOptions).toHaveCount(7); // Auto + 6 quality levels
    
    // Select 720p
    await page.click('[data-level="1"]'); // 720p is index 1
    
    // Verify quality changed
    await expect(page.locator('#quality-text-stream1')).toContainText('720p');
    
    // Check stats update
    await page.waitForTimeout(2000);
    await expect(page.locator('#stat-quality-stream1')).toContainText('720p');
  });

  test('should support DVR timeline seeking', async ({ page }) => {
    // Start a stream
    await page.click('[data-stream="stream1"]');
    await page.waitForSelector('#player-stream1');
    
    // Wait for some content to buffer
    await page.waitForTimeout(10000);
    
    // Get timeline element
    const timeline = page.locator('#timeline-stream1 .timeline');
    
    // Click on timeline to seek back
    const timelineBox = await timeline.boundingBox();
    await page.mouse.click(
      timelineBox.x + timelineBox.width * 0.3, // 30% position
      timelineBox.y + timelineBox.height / 2
    );
    
    // Check GO LIVE button appears
    await expect(page.locator('#live-btn-stream1')).toBeVisible();
    await expect(page.locator('#live-btn-stream1')).toContainText('GO LIVE');
    
    // Click GO LIVE to return to live edge
    await page.click('#live-btn-stream1');
    
    // Verify button disappears
    await expect(page.locator('#live-btn-stream1')).not.toBeVisible();
  });

  test('should display stream statistics', async ({ page }) => {
    // Start a stream
    await page.click('[data-stream="stream1"]');
    await page.waitForSelector('#player-stream1');
    
    // Wait for stats to populate
    await page.waitForTimeout(5000);
    
    // Check stats are updating
    const bitrateText = await page.locator('#stat-bitrate-stream1').textContent();
    expect(parseInt(bitrateText)).toBeGreaterThan(0);
    
    const bufferText = await page.locator('#stat-buffer-stream1').textContent();
    expect(parseFloat(bufferText)).toBeGreaterThan(0);
    
    const latencyText = await page.locator('#stat-latency-stream1').textContent();
    expect(parseInt(latencyText)).toBeGreaterThan(0);
  });

  test('should handle stream removal', async ({ page }) => {
    // Start a stream
    await page.click('[data-stream="stream1"]');
    await page.waitForSelector('#player-stream1');
    
    // Click stream again to remove
    await page.click('[data-stream="stream1"]');
    
    // Verify player is removed
    await expect(page.locator('#player-stream1')).not.toBeVisible();
    
    // Verify stream is not marked as active
    await expect(page.locator('[data-stream="stream1"]')).not.toHaveClass(/active/);
  });

  test('should show system logs', async ({ page }) => {
    // Check initial log entry
    await expect(page.locator('.log-entry')).toHaveCount(1);
    
    // Start a stream
    await page.click('[data-stream="stream1"]');
    
    // Wait for log updates
    await page.waitForTimeout(2000);
    
    // Check new log entries
    const logEntries = page.locator('.log-entry');
    const count = await logEntries.count();
    expect(count).toBeGreaterThan(1);
    
    // Verify log content
    const logs = await logEntries.allTextContents();
    expect(logs.some(log => log.includes('Loading stream'))).toBeTruthy();
    expect(logs.some(log => log.includes('Manifest loaded'))).toBeTruthy();
  });

  test('should prevent more than 4 concurrent streams', async ({ page }) => {
    // Start 4 streams (maximum)
    for (let i = 1; i <= 3; i++) {
      await page.click(`[data-stream="stream${i}"]`);
      await page.waitForSelector(`#player-stream${i}`);
    }
    
    // Try to add a 5th stream (we only have 3 test streams, so click stream1 again)
    await page.click('[data-stream="stream1"]');
    
    // Should remove stream1 instead of adding it again
    await expect(page.locator('#player-stream1')).not.toBeVisible();
  });
});

test.describe('Transcoder API Tests', () => {
  test('should verify transcoder health', async ({ request }) => {
    const response = await request.get(`${TRANSCODER_URL}/health`);
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data.status).toBe('healthy');
    expect(data.service).toBe('transcoder');
  });

  test('should get quality profiles', async ({ request }) => {
    const response = await request.get(`${TRANSCODER_URL}/qualities`);
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data.success).toBe(true);
    expect(data.count).toBe(6);
    
    // Verify quality levels
    const qualities = data.data;
    expect(qualities[0].name).toBe('1080p');
    expect(qualities[1].name).toBe('720p');
    expect(qualities[2].name).toBe('480p');
    expect(qualities[3].name).toBe('360p');
    expect(qualities[4].name).toBe('240p');
    expect(qualities[5].name).toBe('144p');
  });

  test('should start and stop transcoders', async ({ request }) => {
    const streamKey = 'test-stream';
    
    // Start transcoder
    let response = await request.post(`${TRANSCODER_URL}/transcode/start/${streamKey}`);
    expect(response.ok()).toBeTruthy();
    
    let data = await response.json();
    expect(data.success).toBe(true);
    expect(data.stream_key).toBe(streamKey);
    
    // Check status
    response = await request.get(`${TRANSCODER_URL}/transcode/status/${streamKey}`);
    expect(response.ok()).toBeTruthy();
    
    data = await response.json();
    expect(data.success).toBe(true);
    expect(data.data.status).toBe('running');
    
    // Stop transcoder
    response = await request.post(`${TRANSCODER_URL}/transcode/stop/${streamKey}`);
    expect(response.ok()).toBeTruthy();
    
    data = await response.json();
    expect(data.success).toBe(true);
  });
});

// Performance tests
test.describe('Performance Tests', () => {
  test('should maintain low latency with multiple streams', async ({ page }) => {
    // Start 3 concurrent streams
    for (const stream of STREAMS) {
      await page.click(`[data-stream="${stream}"]`);
      await page.waitForSelector(`#player-${stream}`);
    }
    
    // Wait for streams to stabilize
    await page.waitForTimeout(10000);
    
    // Check latency for each stream
    for (const stream of STREAMS) {
      const latencyText = await page.locator(`#stat-latency-${stream}`).textContent();
      const latency = parseInt(latencyText);
      
      // Latency should be under 500ms
      expect(latency).toBeLessThan(500);
    }
  });

  test('should maintain stable buffer levels', async ({ page }) => {
    // Start multiple streams
    for (const stream of STREAMS) {
      await page.click(`[data-stream="${stream}"]`);
      await page.waitForSelector(`#player-${stream}`);
    }
    
    // Monitor buffer levels over time
    const bufferReadings = [];
    
    for (let i = 0; i < 5; i++) {
      await page.waitForTimeout(2000);
      
      for (const stream of STREAMS) {
        const bufferText = await page.locator(`#stat-buffer-${stream}`).textContent();
        const buffer = parseFloat(bufferText);
        bufferReadings.push(buffer);
      }
    }
    
    // All buffer readings should be above 2 seconds
    expect(Math.min(...bufferReadings)).toBeGreaterThan(2);
    
    // No excessive buffering (under 30 seconds)
    expect(Math.max(...bufferReadings)).toBeLessThan(30);
  });
});