# Use lightweight Node image
FROM node:18-alpine

# Author label (important for your showcase)
LABEL maintainer="Rajamohan"
LABEL description="Enterprise DevSecOps Sample App"

# Set working directory
WORKDIR /app

# Copy package files first (better caching)
COPY package*.json ./

# Install dependencies
RUN npm install --only=production

# Copy source code
COPY src ./src

# Expose port
EXPOSE 3000

# Run as non-root user
USER 10001

# Run application
CMD ["npm", "start"]