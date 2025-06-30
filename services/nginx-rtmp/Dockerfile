# Enhanced NGINX-RTMP Docker image for StreamForge
FROM tiangolo/nginx-rtmp

# Install ffmpeg and additional tools for better streaming
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    procps \
    net-tools \
    htop \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Copy the enhanced configuration that includes exec directive
COPY nginx-enhanced.conf /etc/nginx/nginx.conf

# Copy the stream lifecycle scripts
COPY on_publish.sh /usr/local/bin/on_publish.sh
COPY on_publish_done.sh /usr/local/bin/on_publish_done.sh
RUN chmod +x /usr/local/bin/on_publish*.sh

# Create necessary directories with proper permissions
RUN mkdir -p /tmp/hls_shared /tmp/recordings /var/log/streamforge \
    && chmod 755 /tmp/hls_shared /tmp/recordings \
    && chmod 755 /var/log/streamforge

# Create streamforge user for better security
RUN groupadd -r streamforge && useradd -r -g streamforge streamforge \
    && chown -R streamforge:streamforge /tmp/hls_shared /tmp/recordings /var/log/streamforge

# Copy all scripts and make them executable
COPY transcode-enhanced.sh /usr/local/bin/transcode.sh
COPY health-check.sh /usr/local/bin/health-check.sh
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /usr/local/bin/transcode.sh /usr/local/bin/health-check.sh /docker-entrypoint.sh

# Expose ports
EXPOSE 1935 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD /usr/local/bin/health-check.sh

# Set entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
