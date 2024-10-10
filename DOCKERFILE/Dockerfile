# Start from the official NGINX image
FROM nginx:alpine

# Create the index.html file during the build
RUN echo "<html><body><h1>Hello, World! This is built by Nedal Akasha for CloudRide Test .</h1></body></html>" > /usr/share/nginx/html/index.html

# Expose port 80 for the web server
EXPOSE 80
