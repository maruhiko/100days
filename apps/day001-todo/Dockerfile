FROM ruby:3.2.8-slim

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libyaml-dev \
      libsqlite3-dev \
      nodejs \
      yarn \
      git \
      sqlite3 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install

COPY . .

EXPOSE 3000
CMD ["sh", "-c", "rm -f tmp/pids/server.pid && bin/rails server -b 0.0.0.0"]
