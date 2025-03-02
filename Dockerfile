FROM elixir:1.17.3-otp-27-alpine AS builder

ENV MIX_ENV=prod

RUN apk add --no-cache git

WORKDIR /app

COPY mix.exs mix.lock ./

RUN mix deps.get --only prod && \
    mix deps.compile

COPY . .

RUN mix release --no-deps-check --overwrite

FROM alpine:3.20.2

ENV MIX_ENV=prod

RUN apk add --no-cache openssl ncurses-libs libgcc libstdc++

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/vennie ./

CMD ["./bin/vennie", "start"]
