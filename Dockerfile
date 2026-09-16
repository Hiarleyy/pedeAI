FROM ruby:3.3.6-slim
ARG APP_VERSION=development
ARG SOURCE_COMMIT=unknown
ARG BUILD_TIMESTAMP=unknown
ENV RAILS_ENV=production \
    BUNDLE_PATH=/usr/local/bundle \
    PORT=3000 \
    APP_VERSION=${APP_VERSION} \
    SOURCE_COMMIT=${SOURCE_COMMIT} \
    BUILD_TIMESTAMP=${BUILD_TIMESTAMP}
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential libpq-dev curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN bundle install
COPY . .
RUN chmod +x bin/pedeai-entrypoint && rm -rf tmp/cache
EXPOSE 3000
ENTRYPOINT ["/app/bin/pedeai-entrypoint"]
CMD ["web"]
