FROM node:18-slim

WORKDIR /evidence

# Copy package files first for layer caching
COPY evidence_mlb/package.json evidence_mlb/package-lock.json /evidence/

# Install dependencies
RUN npm ci

# Copy project files
COPY evidence_mlb/ /evidence/

EXPOSE 3000

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
