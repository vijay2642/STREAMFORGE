// Playwright test script to verify HLS quality streaming
const { chromium } = require('playwright');

async function testQualityStreaming() {
  const browser = await chromium.launch({ headless: false });
  const page = await browser.newPage();

  try {
    console.log('🎬 Testing StreamForge Quality Streaming...');
    
    // Navigate to the React player
    await page.goto('http://localhost:3000');
    await page.waitForTimeout(3000);

    // Take initial screenshot
    await page.screenshot({ path: 'initial-page.png' });
    console.log('📸 Initial screenshot taken');

    // Check what streams are available
    const streamOptions = await page.locator('select option').allTextContents();
    console.log('📡 Available streams:', streamOptions);

    // Select stream2 (which is currently active)
    console.log('📡 Selecting stream2...');
    await page.selectOption('select', 'stream2');
    
    // Load the stream
    console.log('⏳ Loading stream...');
    await page.click('button:has-text("Load Stream")');
    await page.waitForTimeout(8000); // Wait longer for HLS to load

    // Take screenshot after load attempt
    await page.screenshot({ path: 'after-load.png' });
    console.log('📸 After load screenshot taken');

    // Check logs on the page
    const logs = await page.locator('.log-entry').allTextContents();
    console.log('📋 Player logs:', logs.slice(-5)); // Show last 5 logs

    // Check if quality selector exists (with more flexible selector)
    const qualitySelector = await page.locator('select.quality-selector, select[value*="p"], select:has(option:text-matches("\\d+p"))');
    const qualitySelectorExists = await qualitySelector.count() > 0;
    
    console.log('🎯 Quality selector exists:', qualitySelectorExists);

    if (qualitySelectorExists) {
      console.log('✅ Quality selector is visible');
      
      // Get available qualities
      const qualities = await page.locator('select.quality-selector option').allTextContents();
      console.log('🎯 Available qualities:', qualities);
      
      // Test each quality
      for (const quality of ['1080p', '720p', '480p', '360p']) {
        console.log(`🔄 Testing ${quality}...`);
        await page.selectOption('select.quality-selector', quality);
        await page.waitForTimeout(3000);
        
        // Check quality indicator
        const indicator = await page.locator('.quality-indicator').textContent();
        console.log(`📊 Quality indicator shows: ${indicator}`);
        
        // Take screenshot
        await page.screenshot({ path: `quality-test-${quality}.png` });
      }
      
      // Test AUTO mode
      console.log('🤖 Testing AUTO mode...');
      await page.selectOption('select.quality-selector', 'auto');
      await page.waitForTimeout(3000);
      
      const autoIndicator = await page.locator('.quality-indicator').textContent();
      console.log(`📊 AUTO mode indicator: ${autoIndicator}`);
      
      console.log('✅ Quality streaming test completed successfully!');
      
    } else {
      console.log('❌ Quality selector not found - stream may not be loaded');
    }

  } catch (error) {
    console.error('❌ Test failed:', error);
  } finally {
    await browser.close();
  }
}

// Run the test
testQualityStreaming();