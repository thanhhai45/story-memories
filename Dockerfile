# syntax=docker/dockerfile:1
# check=error=true

# Image production — được Kamal build và deploy.
#   docker build -t anniversary_memories .
#   docker run -d -p 80:80 -e SECRET_KEY_BASE=... -e DB_HOST=... anniversary_memories

ARG RUBY_VERSION=3.4
FROM docker.io/library/ruby:$RUBY_VERSION-slim-bookworm AS base

WORKDIR /rails

# Gói chạy: libvips (xử lý ảnh), FFmpeg/ffprobe (dựng video), client PostgreSQL
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libvips postgresql-client ffmpeg && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development test" \
    LANG="C.UTF-8"

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock* ./
# Có Gemfile.lock (khuyến nghị, tạo bằng `make lock`) thì cài đúng phiên bản đã khóa.
RUN if [ ! -f Gemfile.lock ]; then BUNDLE_DEPLOYMENT=0 bundle lock; fi && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

# Build Tailwind + digest assets (không cần secret thật)
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p db log storage tmp/renders && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Thruster: nén, cache asset, X-Sendfile trước Puma
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
