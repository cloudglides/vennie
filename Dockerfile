# Use an official Elixir base image from Docker Hub
FROM docker.io/hexpm/elixir:1.17.3-erlang-27.2.2-ubuntu-focal-20241011

# Install git-core (required for fetching dependencies)
RUN apt-get update -y && \
    apt-get install -y git-core && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /bot

# Copy mix files to leverage caching for dependency installation
COPY mix.exs mix.lock ./

# Fetch and compile dependencies
RUN mix do deps.get, deps.compile

# Copy the rest of your project files into the container
COPY . .

# Compile the application code
RUN mix compile

# Define the command to run when the container starts
CMD ["iex", "-S", "mix"]

