import React, { useState, useRef, useEffect, useCallback } from 'react';
import Hls from 'hls.js';
import './StreamPlayer.css';

interface StreamInfo {
  name: string;
  status: string;
  file_count: number;
  last_update: string;
  isNew?: boolean; // Flag for newly discovered streams
}

interface StreamsResponse {
  status: string;
  count: number;
  streams: StreamInfo[];
  timestamp: string;
}

interface ActiveTranscoderInfo {
  stream_key: string;
  status: string;
  start_time: string;
  uptime: string;
  uptime_seconds: number;
  output_dir: string;
  pid: number;
  hls_master: string;
  quality_count: number;
}

interface ActiveTranscodersResponse {
  success: boolean;
  data: ActiveTranscoderInfo[];
  count: number;
}

const SimpleReactPlayer: React.FC = () => {
  const [streamKey, setStreamKey] = useState('stream1');
  const [isLoading, setIsLoading] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [availableStreams, setAvailableStreams] = useState<StreamInfo[]>([]);
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [isLiveEdge, setIsLiveEdge] = useState(true);

  // Quality detection state
  const [currentQuality, setCurrentQuality] = useState('Auto');
  const [detectedResolution, setDetectedResolution] = useState('');
  const [detectedBandwidth, setDetectedBandwidth] = useState('');
  const [showQualityDetails, setShowQualityDetails] = useState(false);

  // Smart auto-refresh state
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isUserInteracting, setIsUserInteracting] = useState(false);
  const [lastAutoRefresh, setLastAutoRefresh] = useState<Date>(new Date());
  const [autoRefreshEnabled, setAutoRefreshEnabled] = useState(true);

  const videoRef = useRef<HTMLVideoElement>(null);
  const hlsRef = useRef<Hls | null>(null);
  const dropdownRef = useRef<HTMLSelectElement>(null);
  const autoRefreshIntervalRef = useRef<NodeJS.Timeout | null>(null);
  
  // Configure server connections
  const host = process.env.REACT_APP_HLS_HOST || window.location.hostname;
  const hlsPort = process.env.REACT_APP_HLS_PORT || '8085';
  const apiPort = process.env.REACT_APP_API_PORT || '8083';

  const addLog = (message: string) => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev.slice(-9), `${timestamp} - ${message}`]);
  };

  // Quality detection function
  const detectQuality = useCallback(() => {
    if (!videoRef.current || !videoRef.current.videoWidth) return;
    
    const width = videoRef.current.videoWidth;
    const height = videoRef.current.videoHeight;
    const resolution = `${width}x${height}`;
    
    let quality = 'Unknown';
    let bandwidth = '';
    
    if (height >= 1080) {
      quality = '1080p';
      bandwidth = '~5.0 Mbps';
    } else if (height >= 720) {
      quality = '720p';
      bandwidth = '~2.8 Mbps';
    } else if (height >= 480) {
      quality = '480p';
      bandwidth = '~1.4 Mbps';
    } else if (height >= 360) {
      quality = '360p';
      bandwidth = '~0.8 Mbps';
    }
    
    setCurrentQuality(quality);
    setDetectedResolution(resolution);
    setDetectedBandwidth(bandwidth);
    
    // Debug log
    console.log('Quality detected:', quality, resolution, bandwidth);
    
    if (quality !== 'Unknown') {
      addLog(`📺 Quality detected: ${quality} (${resolution})`);
    }
  }, []);

  const toggleQualityDetails = () => {
    setShowQualityDetails(!showQualityDetails);
  };

  // Fetch active transcoders from the API
  const fetchActiveTranscoders = useCallback(async (): Promise<ActiveTranscoderInfo[]> => {
    try {
      const response = await fetch(`http://${host}:${apiPort}/transcode/active`);
      const data: ActiveTranscodersResponse = await response.json();

      if (data.success) {
        return data.data;
      }
      return [];
    } catch (error) {
      console.warn('Failed to fetch active transcoders:', error);
      return [];
    }
  }, [host, apiPort]);

  // Smart merge function that preserves user selection and adds new streams
  const smartMergeStreams = useCallback((currentStreams: StreamInfo[], activeTranscoders: ActiveTranscoderInfo[]): StreamInfo[] => {
    const existingStreamKeys = new Set(currentStreams.map(s => s.name));
    const activeStreamKeys = new Set(activeTranscoders.map(t => t.stream_key));

    // Update existing streams with current status
    const updatedStreams = currentStreams.map(stream => ({
      ...stream,
      status: activeStreamKeys.has(stream.name) ? 'active' : 'inactive',
      isNew: false // Clear new flag for existing streams
    }));

    // Add newly discovered streams
    const newStreams: StreamInfo[] = activeTranscoders
      .filter(transcoder => !existingStreamKeys.has(transcoder.stream_key))
      .map(transcoder => ({
        name: transcoder.stream_key,
        status: 'active',
        file_count: transcoder.quality_count,
        last_update: transcoder.start_time,
        isNew: true // Mark as new for visual indication
      }));

    return [...updatedStreams, ...newStreams];
  }, []);

  // Check if it's safe to update (user not actively interacting)
  const isSafeToUpdate = useCallback((): boolean => {
    return !isDropdownOpen && !isUserInteracting && autoRefreshEnabled;
  }, [isDropdownOpen, isUserInteracting, autoRefreshEnabled]);

  // Background auto-refresh function
  const performBackgroundRefresh = useCallback(async () => {
    if (!isSafeToUpdate()) {
      return; // Skip if user is interacting
    }

    try {
      const activeTranscoders = await fetchActiveTranscoders();

      setAvailableStreams(currentStreams => {
        const newStreams = smartMergeStreams(currentStreams, activeTranscoders);

        // Check if there are actually new streams
        const hasNewStreams = newStreams.some(s => s.isNew);
        const activeCount = newStreams.filter(s => s.status === 'active').length;

        if (hasNewStreams) {
          const newStreamNames = newStreams.filter(s => s.isNew).map(s => s.name);
          addLog(`🆕 New streams discovered: ${newStreamNames.join(', ')}`);
        }

        // Update last refresh time
        setLastAutoRefresh(new Date());

        return newStreams;
      });

    } catch (error) {
      console.warn('Background refresh failed:', error);
    }
  }, [isSafeToUpdate, fetchActiveTranscoders, smartMergeStreams, addLog]);

  // Setup auto-refresh interval
  useEffect(() => {
    if (autoRefreshEnabled) {
      // Initial refresh after 2 seconds
      const initialTimeout = setTimeout(performBackgroundRefresh, 2000);

      // Then refresh every 8 seconds
      autoRefreshIntervalRef.current = setInterval(performBackgroundRefresh, 8000);

      return () => {
        clearTimeout(initialTimeout);
        if (autoRefreshIntervalRef.current) {
          clearInterval(autoRefreshIntervalRef.current);
        }
      };
    }
  }, [autoRefreshEnabled, performBackgroundRefresh]);

  const fetchAvailableStreams = async () => {
    setIsRefreshing(true);
    setIsUserInteracting(true); // Prevent auto-refresh during manual refresh

    try {
      // Try to get active transcoders first
      const activeTranscoders = await fetchActiveTranscoders();

      // Also try the legacy streams endpoint as fallback
      let legacyStreams: StreamInfo[] = [];
      try {
        const response = await fetch(`http://${host}:${apiPort}/streams`);
        const data: StreamsResponse = await response.json();
        if (data.status === 'success') {
          legacyStreams = data.streams;
        }
      } catch (legacyError) {
        console.warn('Legacy streams endpoint failed:', legacyError);
      }

      // Merge active transcoders with legacy streams or use live streams only
      const baseStreams = legacyStreams.length > 0 ? legacyStreams.filter(s => 
        s.name === 'stream1' || s.name === 'stream2' || s.name === 'stream3'
      ) : [
        { name: 'stream1', status: 'inactive', file_count: 0, last_update: '' },
        { name: 'stream2', status: 'inactive', file_count: 0, last_update: '' },
        { name: 'stream3', status: 'inactive', file_count: 0, last_update: '' }
      ];

      const mergedStreams = smartMergeStreams(baseStreams, activeTranscoders);
      setAvailableStreams(mergedStreams);

      const activeCount = mergedStreams.filter(s => s.status === 'active').length;
      const totalCount = mergedStreams.length;

      addLog(`🔄 Found ${totalCount} streams (${activeCount} active)`);

      if (activeCount > 0) {
        const activeNames = mergedStreams.filter(s => s.status === 'active').map(s => s.name);
        addLog(`✅ Active: ${activeNames.join(', ')}`);
      } else {
        addLog(`⏳ No active streams - ready for RTMP input`);
      }

    } catch (error) {
      addLog(`❌ Failed to fetch streams: ${error}`);
      // Ultimate fallback - live streams only
      const fallbackStreams: StreamInfo[] = [
        { name: 'stream1', status: 'inactive', file_count: 0, last_update: '' },
        { name: 'stream2', status: 'inactive', file_count: 0, last_update: '' },
        { name: 'stream3', status: 'inactive', file_count: 0, last_update: '' }
      ];
      setAvailableStreams(fallbackStreams);
      addLog(`🔧 Using live streams only: stream1, stream2, stream3`);
    } finally {
      setIsRefreshing(false);
      // Allow auto-refresh again after a short delay
      setTimeout(() => setIsUserInteracting(false), 1000);
    }
  };

  const loadStream = () => {
    if (!streamKey.trim()) {
      addLog('❌ Please select a stream');
      return;
    }

    setIsLoading(true);
    const streamUrl = `http://${host}:${hlsPort}/hls/${streamKey}/master.m3u8`;
    addLog(`📡 Loading stream: ${streamKey}`);
    addLog(`🔗 URL: ${streamUrl}`);
    
    if (!videoRef.current) {
      addLog('❌ Video element not found');
      setIsLoading(false);
      return;
    }

    // Cleanup existing HLS instance
    if (hlsRef.current) {
      hlsRef.current.destroy();
      hlsRef.current = null;
    }

    if (Hls.isSupported()) {
      addLog('🔧 Using HLS.js for playback');
      addLog('⚡ Low-latency mode enabled (6s target latency)');
      
      const hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        liveSyncDurationCount: 3,     // 3 × 2s = 6s latency per O3 communication
        liveMaxLatencyDurationCount: 5,
        backBufferLength: 30,         // 30 seconds back buffer per O3 communication
        maxBufferLength: 15,          // Reduced for lower latency
        maxMaxBufferLength: 30,       // Reduced for lower latency
        manifestLoadingTimeOut: 5000,
        fragLoadingTimeOut: 5000,
        liveDurationInfinity: true,   // Enable live streaming mode
        
        // SMART QUALITY DEFAULTS - Start High, Adapt Down Only If Needed
        startLevel: 0,                           // Always start with highest (1080p)
        autoStartLoad: true,                     // Auto start loading
        abrEwmaDefaultEstimate: 100000000,       // Assume 100 Mbps bandwidth
        abrEwmaSlowVoD: 0.99,                   // Extremely slow to adapt down
        abrEwmaFastVoD: 0.99,                   // Extremely slow to adapt down  
        abrBandWidthFactor: 0.7,                // Only switch down at 70% estimated bandwidth
        abrBandWidthUpFactor: 0.8,              // Switch up at 80% bandwidth usage
        abrMaxWithRealBitrate: false,           // Don't use real measured bitrate initially
        capLevelToPlayerSize: false,            // Don't limit quality to player size
        testBandwidth: false,                   // Skip initial bandwidth test
        
        debug: false
      });
      
      hls.loadSource(streamUrl);
      hls.attachMedia(videoRef.current);
      
      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        addLog('✅ HLS manifest loaded successfully');
        addLog(`🎯 Available levels: ${hls.levels.length}`);
        hls.levels.forEach((level, index) => {
          addLog(`Level ${index}: ${level.height}p (${level.width}x${level.height}) ${Math.round(level.bitrate/1000)}k`);
        });
        
        // Force to highest quality (1080p) immediately
        if (hls.levels.length > 0) {
          hls.currentLevel = 0; // Force level 0 (1080p)
          addLog(`🚀 FORCED to Level 0 (1080p): ${hls.levels[0].height}p`);
        }
        
        videoRef.current?.play().catch(err => {
          addLog(`⚠️ Autoplay blocked: ${err.message}`);
        });
        setIsLoading(false);
        // Detect quality after manifest is loaded
        setTimeout(detectQuality, 1000);
      });

      // Track live edge position and quality
      hls.on(Hls.Events.FRAG_LOADED, () => {
        if (videoRef.current && hls.liveSyncPosition !== null) {
          const currentTime = videoRef.current.currentTime;
          const liveEdge = hls.liveSyncPosition;
          const timeBehind = liveEdge - currentTime;
          
          // Consider "live" if within 10 seconds of live edge
          setIsLiveEdge(timeBehind < 10);
          
          // Detect quality periodically
          detectQuality();
        }
      });

      // Listen for quality level changes
      hls.on(Hls.Events.LEVEL_SWITCHED, (event, data) => {
        const level = hls.levels[data.level];
        addLog(`🎯 Quality switched to level ${data.level}: ${level.height}p (${level.width}x${level.height})`);
        
        // If it's not 1080p (level 0), force it back to 1080p
        if (data.level !== 0 && hls.levels.length > 0) {
          setTimeout(() => {
            hls.currentLevel = 0;
            addLog(`🔒 Auto-corrected back to Level 0 (1080p) from ${level.height}p`);
          }, 100);
        }
        
        setTimeout(detectQuality, 500); // Detect after level switch
      });

      // Force to highest quality after manifest loads
      hls.on(Hls.Events.MANIFEST_LOADED, () => {
        addLog(`🎯 Manifest loaded - forcing 1080p start...`);
        hls.currentLevel = 0; // Force highest quality (1080p)
        addLog(`🚀 Set currentLevel = 0 (1080p)`);
        addLog(`📊 Current level after setting: ${hls.currentLevel}`);
      });

      // Log ABR decisions to understand quality switching
      hls.on(Hls.Events.LEVEL_SWITCHING, (event, data) => {
        const level = hls.levels[data.level];
        addLog(`⚡ Switching TO level ${data.level}: ${level.height}p`);
      });
      
      hls.on(Hls.Events.ERROR, (event, data) => {
        addLog(`❌ HLS Error: ${data.details}`);
        
        if (data.fatal) {
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              addLog('🔄 Network error - retrying...');
              setTimeout(() => {
                hls.startLoad();
              }, 1000);
              break;
              
            case Hls.ErrorTypes.MEDIA_ERROR:
              addLog('🔧 Media error - recovering...');
              hls.recoverMediaError();
              break;
              
            default:
              addLog('💀 Fatal HLS error');
              setIsLoading(false);
              break;
          }
        } else {
          // Handle non-fatal codec errors
          if (data.details === 'bufferAddCodecError' || data.details === 'bufferAppendError') {
            addLog('🔧 Codec issue - attempting recovery...');
            hls.recoverMediaError();
          }
        }
      });
      
      hlsRef.current = hls;
      
    } else if (videoRef.current.canPlayType('application/vnd.apple.mpegurl')) {
      addLog('🍎 Using native HLS support (Safari)');
      videoRef.current.src = streamUrl;
      videoRef.current.load();
      
      videoRef.current.addEventListener('loadedmetadata', () => {
        addLog('🎯 Native HLS loaded');
        videoRef.current?.play().catch(err => {
          addLog(`⚠️ Autoplay blocked: ${err.message}`);
        });
        setIsLoading(false);
      }, { once: true });
      
    } else {
      addLog('❌ HLS not supported in this browser');
      setIsLoading(false);
    }
  };

  const clearLogs = () => {
    setLogs([]);
  };

  const goToLive = () => {
    if (!videoRef.current) return;
    
    addLog('🔴 Jumping to LIVE edge...');
    
    if (hlsRef.current) {
      // HLS.js method to seek to live edge
      if (hlsRef.current.liveSyncPosition !== null) {
        videoRef.current.currentTime = hlsRef.current.liveSyncPosition;
        addLog('🎯 Seeked to live edge via HLS.js');
      } else {
        // Fallback: seek to end of buffer
        const duration = videoRef.current.duration;
        if (duration && duration > 0) {
          videoRef.current.currentTime = duration;
          addLog('🎯 Seeked to buffer end');
        }
      }
    } else {
      // Native HLS: seek to end
      const duration = videoRef.current.duration;
      if (duration && duration > 0) {
        videoRef.current.currentTime = duration;
        addLog('🎯 Seeked to live edge (native)');
      }
    }
    
    // Ensure playback continues
    videoRef.current.play().catch(err => {
      addLog(`⚠️ Play after live seek: ${err.message}`);
    });
  };

  const force1080p = () => {
    if (!hlsRef.current) {
      addLog('❌ HLS not available');
      return;
    }
    
    if (hlsRef.current.levels && hlsRef.current.levels.length > 0) {
      hlsRef.current.currentLevel = 0; // Force level 0 (highest quality)
      addLog('🚀 Manually forced to 1080p (Level 0)');
      setTimeout(detectQuality, 1000);
    } else {
      addLog('❌ No quality levels available');
    }
  };

  useEffect(() => {
    addLog('🚀 React Stream Player Ready');
    addLog(`📱 HLS.js supported: ${Hls.isSupported()}`);
    
    // Fetch available streams on load
    fetchAvailableStreams();
    
    // Set up quality detection interval
    const qualityInterval = setInterval(detectQuality, 3000);
    
    return () => {
      // Cleanup HLS on unmount
      if (hlsRef.current) {
        hlsRef.current.destroy();
      }
      clearInterval(qualityInterval);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="stream-player">
      <div className="player-header">
        <h1>⚛️ React Live Stream Player</h1>
        <p>Available Streams: {availableStreams.length} configured | {availableStreams.filter(s => s.status === 'active').length} active</p>

        {/* Auto-refresh status and controls */}
        <div className="auto-refresh-panel" style={{
          fontSize: '14px',
          color: '#666',
          marginTop: '10px',
          display: 'flex',
          alignItems: 'center',
          gap: '15px',
          flexWrap: 'wrap'
        }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span>🔄 Auto-refresh:</span>
            <button
              onClick={() => setAutoRefreshEnabled(!autoRefreshEnabled)}
              style={{
                padding: '4px 8px',
                fontSize: '12px',
                border: '1px solid #ccc',
                borderRadius: '4px',
                background: autoRefreshEnabled ? '#e8f5e8' : '#f5f5f5',
                color: autoRefreshEnabled ? '#2d5a2d' : '#666',
                cursor: 'pointer'
              }}
            >
              {autoRefreshEnabled ? '✅ ON' : '❌ OFF'}
            </button>
          </div>

          <div style={{ fontSize: '12px', color: '#888' }}>
            Last update: {lastAutoRefresh.toLocaleTimeString()}
          </div>

          {isUserInteracting && (
            <div style={{ fontSize: '12px', color: '#ff6b35' }}>
              ⏸️ Paused (user interacting)
            </div>
          )}

          {availableStreams.some(s => s.isNew) && (
            <div style={{ fontSize: '12px', color: '#4CAF50', fontWeight: 'bold' }}>
              🆕 New streams detected!
            </div>
          )}
        </div>
      </div>

      <div className="player-controls">
        <div className="control-group">
          <select
            ref={dropdownRef}
            value={streamKey}
            onChange={(e) => {
              setStreamKey(e.target.value);
              // Clear new flag when user selects a stream
              setAvailableStreams(prev => prev.map(s => ({ ...s, isNew: false })));
            }}
            onFocus={() => {
              setIsDropdownOpen(true);
              setIsUserInteracting(true);
            }}
            onBlur={() => {
              setIsDropdownOpen(false);
              // Allow auto-refresh again after a short delay
              setTimeout(() => setIsUserInteracting(false), 500);
            }}
            onMouseEnter={() => setIsUserInteracting(true)}
            onMouseLeave={() => setIsUserInteracting(false)}
            className="stream-input"
            style={{ maxWidth: '300px', padding: '12px', fontSize: '16px' }}
            disabled={false}
          >
            {availableStreams.length > 0 ? (
              availableStreams.map((stream) => (
                <option key={stream.name} value={stream.name}>
                  {stream.status === 'active' ? '🔴' : '⚪'}
                  {stream.isNew ? '🆕 ' : ''}
                  {stream.name.toUpperCase()}
                  {stream.status === 'active' ? ' (LIVE)' : ' (Ready)'}
                  {stream.file_count > 0 ? ` - ${stream.file_count} files` : ''}
                </option>
              ))
            ) : (
              <option value="">🔄 Loading streams...</option>
            )}
          </select>
          <button 
            onClick={loadStream}
            disabled={isLoading || !streamKey}
            className="load-btn"
            style={{ marginLeft: '15px' }}
          >
            {isLoading ? '⏳ Loading...' : '📡 Load Stream'}
          </button>
          <button 
            onClick={fetchAvailableStreams}
            disabled={isRefreshing}
            className="refresh-btn"
            style={{ marginLeft: '10px' }}
          >
            {isRefreshing ? '🔄 Refreshing...' : '🔄 Refresh Streams'}
          </button>
          <button 
            onClick={goToLive}
            disabled={!streamKey || isLoading}
            className="live-btn"
            style={{ 
              marginLeft: '10px',
              backgroundColor: isLiveEdge ? '#00aa00' : '#ff4444',
              color: 'white',
              fontWeight: 'bold',
              border: isLiveEdge ? '2px solid #00ff00' : '2px solid #ff6666',
              padding: '12px 20px',
              borderRadius: '6px',
              cursor: 'pointer',
              boxShadow: isLiveEdge ? '0 0 10px rgba(0,255,0,0.5)' : '0 0 10px rgba(255,68,68,0.5)',
              transition: 'all 0.3s ease'
            }}
          >
            {isLiveEdge ? '🟢 LIVE' : '🔴 GO LIVE'}
          </button>
          <button 
            onClick={clearLogs} 
            className="clear-btn"
            style={{ marginLeft: '10px' }}
          >
            🗑️ Clear Logs
          </button>
          <button 
            onClick={force1080p}
            disabled={!streamKey || isLoading}
            className="quality-btn"
            style={{ 
              marginLeft: '10px',
              backgroundColor: '#FF6B6B',
              color: 'white',
              fontWeight: 'bold',
              border: '2px solid #FF9999',
              padding: '12px 20px',
              borderRadius: '6px',
              cursor: 'pointer'
            }}
          >
            🎯 Force 1080p
          </button>
        </div>
      </div>

      <div className="player-wrapper" style={{ position: 'relative' }}>
        {/* Quality Widget Overlay */}
        <div 
          style={{
            position: 'absolute',
            top: '15px',
            right: '15px',
            zIndex: 9999,
            fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
            pointerEvents: 'none'
          }}
        >
          <div 
            onClick={toggleQualityDetails}
            style={{
              background: 'rgba(0, 0, 0, 0.85)',
              color: 'white',
              padding: '10px 16px',
              borderRadius: '25px',
              fontSize: '14px',
              fontWeight: '600',
              border: `2px solid ${currentQuality === '1080p' ? '#FF6B6B' : 
                                  currentQuality === '720p' ? '#4ECDC4' : 
                                  currentQuality === '480p' ? '#45B7D1' : 
                                  currentQuality === '360p' ? '#96CEB4' : '#4CAF50'}`,
              backdropFilter: 'blur(15px)',
              boxShadow: '0 4px 20px rgba(0, 0, 0, 0.4)',
              pointerEvents: 'auto',
              cursor: 'pointer',
              transition: 'all 0.3s ease',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            <span 
              style={{
                width: '8px',
                height: '8px',
                borderRadius: '50%',
                background: '#4CAF50',
                display: 'inline-block',
                animation: 'pulse 2s infinite'
              }}
            />
            📺 {currentQuality || 'Auto'} {detectedResolution && `- ${detectedResolution}`} {detectedBandwidth && `@ ${detectedBandwidth.replace('~', '')}`}
          </div>
          
          {showQualityDetails && (
            <div 
              style={{
                position: 'absolute',
                top: '100%',
                right: '0',
                marginTop: '10px',
                background: 'rgba(0, 0, 0, 0.9)',
                color: 'white',
                padding: '15px',
                borderRadius: '10px',
                backdropFilter: 'blur(20px)',
                boxShadow: '0 8px 32px rgba(0, 0, 0, 0.5)',
                minWidth: '220px',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                pointerEvents: 'auto'
              }}
            >
              <div style={{ marginBottom: '12px', fontWeight: 'bold', color: '#4CAF50', textAlign: 'center' }}>
                📺 Stream Quality Info
              </div>
              <div style={{ margin: '8px 0', display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: '#4CAF50', fontWeight: '500' }}>Quality:</span>
                <span style={{ color: 'white', fontWeight: '600' }}>{currentQuality}</span>
              </div>
              <div style={{ margin: '8px 0', display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: '#4CAF50', fontWeight: '500' }}>Resolution:</span>
                <span style={{ color: 'white', fontWeight: '600' }}>{detectedResolution || '-'}</span>
              </div>
              <div style={{ margin: '8px 0', display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: '#4CAF50', fontWeight: '500' }}>Bandwidth:</span>
                <span style={{ color: 'white', fontWeight: '600' }}>{detectedBandwidth || '-'}</span>
              </div>
              <div style={{ margin: '8px 0', display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ color: '#4CAF50', fontWeight: '500' }}>Codec:</span>
                <span style={{ color: 'white', fontWeight: '600' }}>
                  {currentQuality === '1080p' ? 'H.264 Level 4.0' : 
                   currentQuality === '720p' ? 'H.264 Level 3.1' :
                   currentQuality === '480p' ? 'H.264 Level 3.1' :
                   currentQuality === '360p' ? 'H.264 Level 3.0' : 'H.264'}
                </span>
              </div>
              <div style={{ marginTop: '12px', fontSize: '11px', opacity: '0.7', textAlign: 'center' }}>
                📊 Real-time quality monitoring
              </div>
            </div>
          )}
        </div>

        <video
          ref={videoRef}
          controls
          muted
          playsInline
          style={{ 
            width: '100%', 
            height: '400px', 
            backgroundColor: '#000',
            borderRadius: '8px'
          }}
          onLoadStart={() => addLog('📥 Loading started')}
          onLoadedData={() => {
            addLog('📊 Stream data loaded');
            detectQuality();
          }}
          onLoadedMetadata={() => {
            addLog('📋 Metadata loaded');
            detectQuality();
          }}
          onCanPlay={() => addLog('✅ Ready to play')}
          onPlay={() => {
            addLog('▶️ Playing');
            detectQuality();
          }}
          onPause={() => addLog('⏸️ Paused')}
          onWaiting={() => addLog('⏳ Buffering...')}
          onError={() => addLog('❌ Stream error')}
          onSeeked={() => {
            addLog('⏪ User seeked in video');
            // Check if still at live edge after seek
            if (hlsRef.current && hlsRef.current.liveSyncPosition !== null && videoRef.current) {
              const timeBehind = hlsRef.current.liveSyncPosition - videoRef.current.currentTime;
              setIsLiveEdge(timeBehind < 10);
            }
          }}
          onTimeUpdate={() => {
            // Continuously check live edge status during playback
            if (hlsRef.current && hlsRef.current.liveSyncPosition !== null && videoRef.current) {
              const timeBehind = hlsRef.current.liveSyncPosition - videoRef.current.currentTime;
              setIsLiveEdge(timeBehind < 10);
            }
          }}
        />
      </div>

      <div className="player-status">
        <div className="status-grid">
          <div className="status-item">
            <strong>Selected Stream:</strong> {streamKey}
          </div>
          <div className="status-item">
            <strong>Status:</strong> {isLoading ? 'Loading...' : isLiveEdge ? '🟢 LIVE' : '⏰ Behind Live'}
          </div>
          <div className="status-item">
            <strong>Type:</strong> HLS Live Stream
          </div>
          <div className="status-item">
            <strong>Server:</strong> {host}:{hlsPort}
          </div>
        </div>
      </div>

      <div className="logs-container">
        <h3>📋 Stream Events</h3>
        <div className="logs">
          {logs.map((log, index) => (
            <div key={index} className="log-entry info">
              <span className="log-message">{log}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="setup-section">
        <h3>🎯 Your Live Streaming Setup</h3>
        <div className="setup-grid">
          <div className="setup-card rtmp">
            <h4>📡 RTMP Publishing</h4>
            <div className="setup-code">
              rtmp://{host === 'localhost' ? '188.245.163.8' : host}:1935/live/stream1<br/>
              rtmp://{host === 'localhost' ? '188.245.163.8' : host}:1935/live/stream2<br/>
              rtmp://{host === 'localhost' ? '188.245.163.8' : host}:1935/live/stream3
            </div>
          </div>
          <div className="setup-card hls">
            <h4>🎬 HLS Playback</h4>
            <div className="setup-code">
              http://{host}:{hlsPort}/hls/stream1/master.m3u8<br/>
              http://{host}:{hlsPort}/hls/stream2/master.m3u8<br/>
              http://{host}:{hlsPort}/hls/stream3/master.m3u8
            </div>
          </div>
          <div className="setup-card features">
            <h4>⚛️ React Features</h4>
            <ul className="setup-list">
              <li>Live stream selection</li>
              <li>Real-time event logging</li>
              <li>Professional UI/UX</li>
              <li>Error handling</li>
            </ul>
          </div>
          <div className="setup-card usage">
            <h4>🔧 Usage</h4>
            <ul className="setup-list">
              <li>Select your stream from dropdown</li>
              <li>Click "Load Stream"</li>
              <li>Watch logs for feedback</li>
              <li>Use video controls to play</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SimpleReactPlayer;