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

  // Smart auto-refresh state
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const [isUserInteracting, setIsUserInteracting] = useState(false);
  const [lastAutoRefresh, setLastAutoRefresh] = useState<Date>(new Date());
  const [autoRefreshEnabled, setAutoRefreshEnabled] = useState(true);

  // Connection quality monitoring
  const [connectionQuality, setConnectionQuality] = useState<'excellent' | 'good' | 'poor' | 'critical'>('good');
  const [currentBandwidth, setCurrentBandwidth] = useState<number>(0);
  const [bufferHealth, setBufferHealth] = useState<number>(0);
  const [qualityLocked, setQualityLocked] = useState(false);

  const videoRef = useRef<HTMLVideoElement>(null);
  const hlsRef = useRef<Hls | null>(null);
  const dropdownRef = useRef<HTMLSelectElement>(null);
  const autoRefreshIntervalRef = useRef<NodeJS.Timeout | null>(null);
  
  // Configure HLS server connection
  const host = process.env.REACT_APP_HLS_HOST || window.location.hostname;
  const port = process.env.REACT_APP_HLS_PORT || '8083';

  const addLog = (message: string) => {
    const timestamp = new Date().toLocaleTimeString();
    setLogs(prev => [...prev.slice(-9), `${timestamp} - ${message}`]);
  };

  // Fetch active transcoders from the API
  const fetchActiveTranscoders = useCallback(async (): Promise<ActiveTranscoderInfo[]> => {
    try {
      const response = await fetch(`http://${host}:${port}/transcode/active`);
      const data: ActiveTranscodersResponse = await response.json();

      if (data.success) {
        return data.data;
      }
      return [];
    } catch (error) {
      console.warn('Failed to fetch active transcoders:', error);
      return [];
    }
  }, [host, port]);

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
        const response = await fetch(`http://${host}:${port}/streams`);
        const data: StreamsResponse = await response.json();
        if (data.status === 'success') {
          legacyStreams = data.streams;
        }
      } catch (legacyError) {
        console.warn('Legacy streams endpoint failed:', legacyError);
      }

      // Merge active transcoders with legacy streams or use fallback
      const baseStreams = legacyStreams.length > 0 ? legacyStreams : [
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
      // Ultimate fallback
      const fallbackStreams: StreamInfo[] = [
        { name: 'stream1', status: 'inactive', file_count: 0, last_update: '' },
        { name: 'stream2', status: 'inactive', file_count: 0, last_update: '' },
        { name: 'stream3', status: 'inactive', file_count: 0, last_update: '' }
      ];
      setAvailableStreams(fallbackStreams);
      addLog(`🔧 Using fallback streams: stream1, stream2, stream3`);
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
    const streamUrl = `http://${host}:${port}/hls/${streamKey}/master.m3u8`;
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
      addLog('⚡ Adaptive streaming enabled for all connection types');

      // Adaptive configuration based on connection quality
      const getHLSConfig = () => {
        const baseConfig = {
          enableWorker: true,
          liveDurationInfinity: true,
          debug: false,
          // Aggressive ABR for poor connections
          abrEwmaFastLive: 3.0,        // Fast adaptation to bandwidth changes
          abrEwmaSlowLive: 9.0,        // Slower smoothing for stability
          abrMaxWithRealBitrate: true, // Use real measured bitrate
          abrBandWidthFactor: 0.7,     // Conservative bandwidth estimation
          abrBandWidthUpFactor: 0.6,   // Even more conservative for upgrades
        };

        // Adjust settings based on connection quality
        switch (connectionQuality) {
          case 'critical':
            return {
              ...baseConfig,
              lowLatencyMode: false,
              liveSyncDurationCount: 1,
              liveMaxLatencyDurationCount: 2,
              maxBufferLength: 4,
              maxMaxBufferLength: 8,
              manifestLoadingTimeOut: 10000,
              fragLoadingTimeOut: 10000,
              abrBandWidthFactor: 0.5,   // Very conservative
              startLevel: 0,             // Force start with lowest quality
            };
          case 'poor':
            return {
              ...baseConfig,
              lowLatencyMode: false,
              liveSyncDurationCount: 2,
              liveMaxLatencyDurationCount: 3,
              maxBufferLength: 6,
              maxMaxBufferLength: 12,
              manifestLoadingTimeOut: 8000,
              fragLoadingTimeOut: 8000,
              abrBandWidthFactor: 0.6,
              startLevel: 0,
            };
          case 'good':
            return {
              ...baseConfig,
              lowLatencyMode: true,
              liveSyncDurationCount: 3,
              liveMaxLatencyDurationCount: 5,
              maxBufferLength: 15,
              maxMaxBufferLength: 30,
              manifestLoadingTimeOut: 5000,
              fragLoadingTimeOut: 5000,
            };
          case 'excellent':
          default:
            return {
              ...baseConfig,
              lowLatencyMode: true,
              liveSyncDurationCount: 2,
              liveMaxLatencyDurationCount: 4,
              maxBufferLength: 20,
              maxMaxBufferLength: 40,
              manifestLoadingTimeOut: 3000,
              fragLoadingTimeOut: 3000,
            };
        }
      };

      const hls = new Hls(getHLSConfig());
      
      hls.loadSource(streamUrl);
      hls.attachMedia(videoRef.current);
      
      hls.on(Hls.Events.MANIFEST_PARSED, () => {
        addLog('✅ HLS manifest loaded successfully');
        videoRef.current?.play().catch(err => {
          addLog(`⚠️ Autoplay blocked: ${err.message}`);
        });
        setIsLoading(false);
      });

      // Track live edge position and connection quality
      hls.on(Hls.Events.FRAG_LOADED, (event, data) => {
        if (videoRef.current && hls.liveSyncPosition !== null) {
          const currentTime = videoRef.current.currentTime;
          const liveEdge = hls.liveSyncPosition;
          const timeBehind = liveEdge - currentTime;

          // Consider "live" if within 10 seconds of live edge
          setIsLiveEdge(timeBehind < 10);

          // Monitor bandwidth and connection quality
          if (data.frag && data.frag.stats) {
            const stats = data.frag.stats;
            const bandwidth = (stats.total * 8) / (stats.loading.end - stats.loading.start); // bits per ms
            const bandwidthKbps = Math.round(bandwidth);

            setCurrentBandwidth(bandwidthKbps);

            // Update connection quality based on bandwidth and buffer health
            const bufferLength = videoRef.current.buffered.length > 0
              ? videoRef.current.buffered.end(0) - videoRef.current.currentTime
              : 0;
            setBufferHealth(bufferLength);

            // Determine connection quality
            let quality: 'excellent' | 'good' | 'poor' | 'critical' = 'good';
            if (bandwidthKbps > 3000 && bufferLength > 5) {
              quality = 'excellent';
            } else if (bandwidthKbps > 1500 && bufferLength > 3) {
              quality = 'good';
            } else if (bandwidthKbps > 800 && bufferLength > 1) {
              quality = 'poor';
            } else {
              quality = 'critical';
            }

            if (quality !== connectionQuality) {
              setConnectionQuality(quality);
              addLog(`📊 Connection: ${quality.toUpperCase()} (${bandwidthKbps} kbps, ${bufferLength.toFixed(1)}s buffer)`);
            }
          }
        }
      });
      
      // Enhanced error handling for poor connections
      hls.on(Hls.Events.ERROR, (event, data) => {
        addLog(`❌ HLS Error: ${data.details}`);

        // Handle buffer stalling for poor connections
        if (data.details === 'bufferStalledError' || data.details === 'bufferNudgeOnStall') {
          if (connectionQuality === 'critical' || connectionQuality === 'poor') {
            addLog('📉 Poor connection detected - forcing lowest quality');
            hls.currentLevel = 0; // Force lowest quality
            setQualityLocked(true);
          }
        }

        // Handle fragment loading errors more aggressively
        if (data.details === 'fragLoadError' || data.details === 'fragLoadTimeOut') {
          const retryDelay = connectionQuality === 'critical' ? 3000 : 1000;
          addLog(`🔄 Fragment error - retrying in ${retryDelay}ms...`);
          setTimeout(() => {
            hls.startLoad();
          }, retryDelay);
          return;
        }

        if (data.fatal) {
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              const networkRetryDelay = connectionQuality === 'critical' ? 5000 : 2000;
              addLog(`🔄 Network error - retrying in ${networkRetryDelay}ms...`);

              // For critical connections, try to restart with lowest quality
              if (connectionQuality === 'critical') {
                setConnectionQuality('critical');
                addLog('🚨 Critical connection - switching to emergency mode');
              }

              setTimeout(() => {
                hls.startLoad();
              }, networkRetryDelay);
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

  useEffect(() => {
    addLog('🚀 React Stream Player Ready');
    addLog(`📱 HLS.js supported: ${Hls.isSupported()}`);
    
    // Fetch available streams on load
    fetchAvailableStreams();
    
    return () => {
      // Cleanup HLS on unmount
      if (hlsRef.current) {
        hlsRef.current.destroy();
      }
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
        </div>
      </div>

      <div className="player-wrapper">
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
          onLoadedData={() => addLog('📊 Stream data loaded')}
          onCanPlay={() => addLog('✅ Ready to play')}
          onPlay={() => addLog('▶️ Playing')}
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
            <strong>Server:</strong> {host}:{port}
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
              http://{host}:{port}/hls/stream1/master.m3u8<br/>
              http://{host}:{port}/hls/stream2/master.m3u8<br/>
              http://{host}:{port}/hls/stream3/master.m3u8
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