# Step 1: Build Jekyll Site
FROM ruby:3.3.4-bullseye AS builder

WORKDIR /app

COPY Gemfile /app/
COPY Gemfile.lock /app/
RUN bundle install

COPY . .

RUN bundle exec jekyll build

# Step 2: Serve with Nginx
FROM nginx:alpine

COPY --from=builder /app/_site /usr/share/nginx/html