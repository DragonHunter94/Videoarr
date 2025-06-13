# Multi-stage build for optimized production image
FROM node:18-alpine as base

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Development stage
FROM base as development
RUN npm install
COPY . .
EXPOSE 3000
CMD ["npm", "start"]

# Builder stage
FROM base as builder
RUN npm ci --only=production
COPY . .
# Build the application with optimizations
ENV NODE_ENV=production
ENV GENERATE_SOURCEMAP=false
ENV REACT_APP_BACKEND_URL=/api
RUN npm run build

# Production stage
FROM nginx:alpine as production

# Install wget for health checks
RUN apk add --no-cache wget

# Copy built app from builder stage
COPY --from=builder /app/build /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create nginx cache directory and set permissions
RUN mkdir -p /var/cache/nginx/client_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Create non-root user for nginx
USER nginx

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]