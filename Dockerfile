FROM ruby:3.3.6-slim
ENV RAILS_ENV=production \
    BUNDLE_PATH=/usr/local/bundle \
    PORT=3000
RUN apt-get update -qq && apt-get install -y --no-install-recommends build-essential libpq-dev curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN bundle install
COPY . .
RUN chmod +x bin/pedeai-entrypoint && rm -rf tmp/cache
EXPOSE 3000
ENTRYPOINT ["/app/bin/pedeai-entrypoint"]
CMD ["web"]
