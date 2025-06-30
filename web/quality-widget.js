/**
 * StreamForge Quality Widget
 * Embeddable quality indicator for any video player
 * 
 * Usage:
 * <script src="quality-widget.js"></script>
 * <script>
 *   const widget = new QualityWidget('your-video-element-id');
 *   widget.showQuality('1080p', '5.0 Mbps', '1920x1080');
 * </script>
 */

class QualityWidget {
    constructor(videoElementId, options = {}) {
        this.videoElement = document.getElementById(videoElementId);
        this.options = {
            position: 'top-right',
            theme: 'dark',
            autoDetect: true,
            showBandwidth: true,
            showResolution: true,
            ...options
        };
        
        this.currentQuality = 'Auto';
        this.currentBandwidth = '';
        this.currentResolution = '';
        
        this.createWidget();
        if (this.options.autoDetect) {
            this.startAutoDetection();
        }
    }
    
    createWidget() {
        // Create widget container
        this.widget = document.createElement('div');
        this.widget.className = 'streamforge-quality-widget';
        this.widget.style.cssText = this.getWidgetStyles();
        
        // Create quality indicator
        this.qualityDisplay = document.createElement('div');
        this.qualityDisplay.className = 'quality-display';
        this.qualityDisplay.style.cssText = this.getQualityDisplayStyles();
        
        // Create details panel
        this.detailsPanel = document.createElement('div');
        this.detailsPanel.className = 'quality-details';
        this.detailsPanel.style.cssText = this.getDetailsPanelStyles();
        this.detailsPanel.style.display = 'none';
        
        // Add click handler for details
        this.qualityDisplay.addEventListener('click', () => {
            this.toggleDetails();
        });
        
        this.widget.appendChild(this.qualityDisplay);
        this.widget.appendChild(this.detailsPanel);
        
        // Position relative to video element
        this.positionWidget();
        
        // Add to DOM
        document.body.appendChild(this.widget);
        
        // Initial update
        this.updateDisplay();
    }
    
    getWidgetStyles() {
        const positions = {
            'top-right': 'top: 15px; right: 15px;',
            'top-left': 'top: 15px; left: 15px;',
            'bottom-right': 'bottom: 15px; right: 15px;',
            'bottom-left': 'bottom: 15px; left: 15px;'
        };
        
        return `
            position: absolute;
            z-index: 9999;
            ${positions[this.options.position] || positions['top-right']}
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            font-size: 13px;
            pointer-events: auto;
        `;
    }
    
    getQualityDisplayStyles() {
        const darkTheme = `
            background: rgba(0, 0, 0, 0.8);
            color: white;
            border: 2px solid #4CAF50;
        `;
        
        const lightTheme = `
            background: rgba(255, 255, 255, 0.9);
            color: #333;
            border: 2px solid #2196F3;
        `;
        
        return `
            padding: 8px 12px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            cursor: pointer;
            font-weight: 600;
            text-align: center;
            transition: all 0.3s ease;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3);
            ${this.options.theme === 'dark' ? darkTheme : lightTheme}
        `;
    }
    
    getDetailsPanelStyles() {
        const darkTheme = `
            background: rgba(0, 0, 0, 0.9);
            color: white;
            border: 1px solid rgba(255, 255, 255, 0.2);
        `;
        
        const lightTheme = `
            background: rgba(255, 255, 255, 0.95);
            color: #333;
            border: 1px solid rgba(0, 0, 0, 0.2);
        `;
        
        return `
            position: absolute;
            top: 100%;
            right: 0;
            margin-top: 8px;
            padding: 12px;
            border-radius: 8px;
            backdrop-filter: blur(15px);
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
            min-width: 200px;
            ${this.options.theme === 'dark' ? darkTheme : lightTheme}
        `;
    }
    
    positionWidget() {
        if (!this.videoElement) return;
        
        const rect = this.videoElement.getBoundingClientRect();
        const scrollTop = window.pageYOffset || document.documentElement.scrollTop;
        const scrollLeft = window.pageXOffset || document.documentElement.scrollLeft;
        
        // Position relative to video element
        this.widget.style.position = 'absolute';
        this.widget.style.top = (rect.top + scrollTop) + 'px';
        this.widget.style.left = (rect.left + scrollLeft) + 'px';
        this.widget.style.width = rect.width + 'px';
        this.widget.style.height = rect.height + 'px';
        this.widget.style.pointerEvents = 'none';
        
        // Enable pointer events only for the quality display
        this.qualityDisplay.style.pointerEvents = 'auto';
        this.detailsPanel.style.pointerEvents = 'auto';
    }
    
    startAutoDetection() {
        if (!this.videoElement) return;
        
        // Monitor video metadata changes
        this.videoElement.addEventListener('loadedmetadata', () => {
            this.detectQuality();
        });
        
        // Monitor resolution changes during playback
        setInterval(() => {
            this.detectQuality();
        }, 2000);
        
        // Reposition on window resize
        window.addEventListener('resize', () => {
            this.positionWidget();
        });
    }
    
    detectQuality() {
        if (!this.videoElement || !this.videoElement.videoWidth) return;
        
        const width = this.videoElement.videoWidth;
        const height = this.videoElement.videoHeight;
        const resolution = `${width}x${height}`;
        
        // Determine quality based on resolution
        let quality = 'Unknown';
        let estimatedBandwidth = '';
        
        if (height >= 1080) {
            quality = '1080p';
            estimatedBandwidth = '~5.0 Mbps';
        } else if (height >= 720) {
            quality = '720p';
            estimatedBandwidth = '~2.8 Mbps';
        } else if (height >= 480) {
            quality = '480p';
            estimatedBandwidth = '~1.4 Mbps';
        } else if (height >= 360) {
            quality = '360p';
            estimatedBandwidth = '~0.8 Mbps';
        }
        
        this.showQuality(quality, estimatedBandwidth, resolution);
    }
    
    showQuality(quality, bandwidth = '', resolution = '') {
        this.currentQuality = quality;
        this.currentBandwidth = bandwidth;
        this.currentResolution = resolution;
        this.updateDisplay();
    }
    
    updateDisplay() {
        // Update main display
        let displayText = `📺 ${this.currentQuality}`;
        if (this.options.showBandwidth && this.currentBandwidth) {
            displayText += ` (${this.currentBandwidth.replace('~', '')})`;
        }
        this.qualityDisplay.textContent = displayText;
        
        // Update details panel
        this.detailsPanel.innerHTML = `
            <div style="margin-bottom: 8px; font-weight: bold; color: #4CAF50;">
                📊 Stream Quality
            </div>
            <div style="margin-bottom: 4px;">
                <strong>Quality:</strong> ${this.currentQuality}
            </div>
            ${this.currentResolution ? `
                <div style="margin-bottom: 4px;">
                    <strong>Resolution:</strong> ${this.currentResolution}
                </div>
            ` : ''}
            ${this.currentBandwidth ? `
                <div style="margin-bottom: 4px;">
                    <strong>Bandwidth:</strong> ${this.currentBandwidth}
                </div>
            ` : ''}
            <div style="margin-top: 8px; font-size: 11px; opacity: 0.7;">
                Click to toggle details
            </div>
        `;
        
        // Update border color based on quality
        const colors = {
            '1080p': '#FF6B6B',
            '720p': '#4ECDC4', 
            '480p': '#45B7D1',
            '360p': '#96CEB4',
            'Auto': '#4CAF50',
            'Unknown': '#9E9E9E'
        };
        
        this.qualityDisplay.style.borderColor = colors[this.currentQuality] || '#4CAF50';
    }
    
    toggleDetails() {
        const isVisible = this.detailsPanel.style.display !== 'none';
        this.detailsPanel.style.display = isVisible ? 'none' : 'block';
    }
    
    setPosition(position) {
        this.options.position = position;
        this.widget.style.cssText = this.getWidgetStyles();
        this.positionWidget();
    }
    
    setTheme(theme) {
        this.options.theme = theme;
        this.qualityDisplay.style.cssText = this.getQualityDisplayStyles();
        this.detailsPanel.style.cssText = this.getDetailsPanelStyles();
        this.updateDisplay();
    }
    
    destroy() {
        if (this.widget && this.widget.parentNode) {
            this.widget.parentNode.removeChild(this.widget);
        }
    }
}

// Make available globally
window.QualityWidget = QualityWidget;

// Auto-initialize if data attributes are present
document.addEventListener('DOMContentLoaded', function() {
    const autoElements = document.querySelectorAll('[data-quality-widget]');
    autoElements.forEach(element => {
        const options = {
            position: element.dataset.position || 'top-right',
            theme: element.dataset.theme || 'dark',
            autoDetect: element.dataset.autoDetect !== 'false',
            showBandwidth: element.dataset.showBandwidth !== 'false',
            showResolution: element.dataset.showResolution !== 'false'
        };
        
        new QualityWidget(element.id, options);
    });
});