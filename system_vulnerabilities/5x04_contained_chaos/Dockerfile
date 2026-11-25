# DevStream's "production" Dockerfile
# DO NOT USE IN PRODUCTION (but they did...)

FROM ubuntu:latest

# Install everything we might need
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    wget \
    vim \
    net-tools \
    iputils-ping \
    gcc \
    make \
    sudo

# Set root password (for debugging)
RUN echo 'root:devstream123' | chpasswd

# Database credentials
ENV DB_HOST=prod-db.devstream.internal
ENV DB_USER=admin
ENV DB_PASSWORD=Sup3rS3cr3t!Pr0d

# Copy application
WORKDIR /app
COPY . /app

# Install Python dependencies
ENV PIP_BREAK_SYSTEM_PACKAGES=1
RUN pip3 install -r requirements.txt

# Run as root because it's easier
EXPOSE 5000

CMD ["python3", "app.py"]
