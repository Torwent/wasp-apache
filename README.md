# wasp-server
 wasp-server is a dockerized ssl encrypted apache server for wasp-webapp

# Setup guide
 This guide is the full setup procedure from scratch in a Debian 11 VPS from https://contabo.com.
 Other distros and/or VPS provides somethings might be slightly different.
 
 ## Setting up non root user
  Start connecting to your VPS by SSH and then login into your VPS as root.
 
  When you are in, the first thing you will want to do is change your root password with:
  ```bash
  passwd root
  ```
  Now let's update and upgrade out system and then install `sudo` since Debian 11 from Contabo doesn't come with it:
  ```bash
  apt update
  apt upgrade
  apt install sudo
  ```
  Make sure you press `Y` and `Enter` when you get prompted.
 
  Now we are ready to create our non root user. You could do everything as root but it's just a bad practice and a security risk.
  ```bash
  adduser torwent
  ```
  I use the alias "Torwent" online, but you can name your user whatever you like.
  Everytime you see `torwent` from now on, you will likely need to use whatever username you used in this command.
  After using this command you will be prompted with a lot of questions, the only important one your have to pay attention is the first 2 which is to setup your password. After that you can answer them or just press Enter on everything, it doesn't really matter.
 
  With our user created we now want to add it to the `sudo` group so we can use commands as root from that user:
  ```bash
  usermod -G sudo torwent
  ```
  
  You can now exit the root user:
  ```bash
  exit
  ```
 
 ## Install Docker and Docker Compose
  Login with the use you created.

  First we are going to install tools we need to be able to add Docker's official repository:
  ```bash
  sudo apt install gnupg
  # Other distros might to install extra things:
  # sudo apt install ca-certificates curl gnupg lsb-release
  ```
  Now we can add Docker's official GPG key:
  ```bash
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  # If you are on Ubuntu change "debian" for "ubuntu".
  ```
  With the GPG key added we can finally add Docker's repository:
  ```bash
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  # Again, if you are on Ubuntu just change "debian" for "ubuntu".
  ```
  We are ready to install Docker now. First update, then install it:
  ```bash
  sudo apt update
  sudo apt install docker-ce docker-ce-cli containerd.io
  ```
  Now Docker is installed. Something you might also want to install is Docker Compose. Either way, if your goal is to follow this tutorial to the end, you will definetly need it.
  Docker Compose allows you setup multiple docker containers easily instead of running a command for each container.
  It's useful to know how to do things without Docker Compose, but as you get into more complex things you will definetly want it.
  
  So, installing Docker Compose is fairly easy, you only need to download it and place it in `/usr/local/bin/`:
  ```bash
  sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  ```
  And now you just have to make it executable:
  ```bash
  sudo chmod +x /usr/local/bin/docker-compose
  ```
  To update Docker Compose in the future you will need to run this 2 commands again.
  And with this you are done. You have both Docker and Docker Compose installed.
  
 ## SSL Setup
  We can start now setting up our server.
  To setup SSL for our server (`https://`) we need to do it in two steps:
  - First we will setup a temporary server to get our SSL certificate
  - When we have our certificate we will setup our real server.
  
  Our server with be an Apache reverse proxy to a node.js app. The same thing can be done with Nginx although the configuration is different and you will need to figure it out yourself.
  Our certificate will be issued by Let's Encrypt with the help of Certbot.
  
  This has one pre-requisite not covered. You need to have a domain name, e.g. waspscripts.com and have that domain pointing to your server ip.
  If you have that done, you are ready to continue!
  
  ### Temporary ACME Challenge Server
   First clone the repository and I recommend you do it in your home directory:
   ```bash
   cd ~/
   git clone https://github.com/Torwent/wasp-server.git
   ```
   This are the contents of wasp-server:
   ```bash
   .
   ├── docs
   │   └── setup.png
   ├── docker-compose.yml
   ├── Dockerfile
   ├── html
   │   └── index.html
   ├── httpd.conf
   ├── LICENSE
   ├── README.md
   └── setup
	   ├── docker-compose.yml
	   ├── Dockerfile
	   ├── html
	   │   └── index.html
	   └── httpd.conf
   ```
   You will want to ignore all the root directory files for now and move into `wasp-server/setup`:
   ```bash
   cd wasp-server/setup
   ```
   Now... you will want to edit the files to match your case.
   The first file is optional but you might want to edit line 2 of `Dockerfile` to whatever you want:
   ```bash
   nano Dockerfile
   ```  
   You can also use VIM if you want and when the file opens this is the second line:
   ```docker
   LABEL author="Torwent"
   ```
   When you are done editing you can close the file.
   If you are using `nano`and are new to it, you close the file by pressing `CTRL+X` and then follow the prompts to save it if you modified it.
   Now let's edit `docker-compose.yml`
   ```bash
   nano docker-compose.yml
   ```
   In this file you will want to modify the last 2 lines to match your case:  
   ```yml
   environment:
     - USER=torwent
     - SERVER=waspscripts.com
   ```
   USER doesn't matter much tbh, but you want to make sure you change the server to **your domain**.
   Close and save the file (`CTRL+X`).
   
   We are now ready to run out temporary server in a docker container!
   You can do so by running the `docker-compose.yml` file using this command:
   ```bash
   sudo docker-compose up -d
   ```
   If you did everything correctly and visit http://waspscripts.com (with your domain obviously), you should see this:
   ![ACME Challenge](https://raw.githubusercontent.com/Torwent/wasp-server/master/docs/setup.png)

  ### Get SSL Certificate
   This following step is only one command but there's a lot of things going on and is what I was struggling the most with setting all this up myself.
   Before showing you the command, I'll try to explain everything that is going on.
   
   - First you need to be sure you are running the temporary server and you can connect to it.
     If you are, you should see something like the picture above.
   - The command will download a certbot/certbot image from Docker Hub.
   - Then we are going to run that image creating a container. This container is going to do a couple of things:
     - It will create a link between bunch of directories in our host system and the container.
	 - Then the container is going to attempt to request a certificate from Let's Encrypt by solving the ACME Challenge to prove you are are who you say you are (honestly this goes over my head but you can read it online).
     - Since we mapped directories from our host system to the directory the container is downloading files to, this will create `/docker/etc/letsencrypt` in our machine.
	 - If everything went well and we passed the ACME Challenge, the files we need will be placed in that directory.

   Let's Encrypt only issues 20 certificates every 7 days per ip so you shouldn't spam the service if you are not passing the challenge.
   Because of that, we are going to run the command in staging mode first:
   ```bash
   sudo docker run -it --rm \
   -v /docker/etc/letsencrypt:/etc/letsencrypt \
   -v /docker/var/lib/letsencrypt:/var/lib/letsencrypt \
   -v /docker/var/log/letsencrypt:/var/log/letsencrypt \
   -v $PWD/html:/data/letsencrypt \
   certbot/certbot certonly --webroot \
   --email torwent@waspscripts.com --agree-tos --no-eff-email --webroot-path=/data/letsencrypt --staging \
   -d waspscripts.com -d www.waspscripts.com -d dev.waspscripts.com -d wasp.waspscripts.com -d blog.waspscripts.com
   ```
   The last line should have all your subdomains with `-d` preeceding them. You should also change the email to your email.
   Also, keep in mind that this assumes you haven't changed the directory from previous steps and are currently in `~/wasp-server/setup`.
   
   If all went well, you should get the following message somewhere:
   ```bash
   Successfully received certificate.
   ```
   Regargless of your result you should now delete `/docker` the directory that was made with this so it doesn't mess with future attempts of the real command:
   ```bash
   sudo rm -rf /docker
   ```
   At this point, if you failed to get your certificate you need to go back and figure out what you did wrong.
   If you did manage to get it, you can run the command without staging:
   ```bash
   sudo docker run -it --rm \
   -v /docker/etc/letsencrypt:/etc/letsencrypt \
   -v /docker/var/lib/letsencrypt:/var/lib/letsencrypt \
   -v /docker/var/log/letsencrypt:/var/log/letsencrypt \
   -v $PWD/html:/data/letsencrypt \
   certbot/certbot certonly --webroot \
   --email torwent@waspscripts.com --agree-tos --no-eff-email --webroot-path=/data/letsencrypt \
   -d waspscripts.com -d www.waspscripts.com -d dev.waspscripts.com -d wasp.waspscripts.com -d blog.waspscripts.com
   ```
   When you have your certificate you can stop your temporary server, we are ready for the real one:
   ```bash
   sudo docker-compose down
   ```
   I also like to clean up docker, but it's optional:
   ```bash
   sudo docker system prune -a
   ```
   
 ## Reverse Proxy Server Setup
  Now that we have our SSL Certificate we are ready for to setup the real deal.
  First of all if you are new to this, I'll explain to you what is a reverse proxy is.
  What we are going to do is run an app, in my case a node.js app in our system without direct connection to the internet.
  A reverse proxy get incoming traffic from the internet and redirects it internally to our app. The main reason to do this is that it allows you to run several apps from a single server.
  
  ### Editing Files
   First we want to move to the main directory of our server:
   ```bash
   cd ~/wasp-server
   ```
   Now you will want to edit the same files we did in `wasp-server/setup` to match your case.
   Again, optionally you can edit line 2 of `Dockerfile` to whatever you want:
   ```bash
   nano Dockerfile
   ```  
   Second line:
   ```docker
   LABEL author="Torwent"
   ```
   Close the file.
   Now let's edit `docker-compose.yml`
   ```bash
   nano docker-compose.yml
   ```
   In this file you will want to modify more lines than we did before:  
   ```yml
   version: "3.9"

   services:
     apache:
       container_name: "apache"
       image: apache:latest
       build:
         context: .
       ports:
         - "80:80"
         - "443:443"
       volumes:
         - ./httpd.conf:/etc/apache2/httpd.conf
         - ./html/:/var/www/html/
         - /docker/etc/letsencrypt/live/waspscripts.com/cert.pem:/etc/letsencrypt/live/waspscripts.com/cert.pem
         - /docker/etc/letsencrypt/live/waspscripts.com/fullchain.pem:/etc/letsencrypt/live/waspscripts.com/fullchain.pem
         - /docker/etc/letsencrypt/live/waspscripts.com/privkey.pem:/etc/letsencrypt/live/waspscripts.com/privkey.pem
         - /docker/server/logs/:/var/www/logs/
       networks:
         - proxy
       environment:
         - USER=torwent
         - SERVER=waspscripts.com

     networks:
       proxy:
         driver: bridge
   ```
   In this file you will want to edit `waspscripts.com` to your domain in `volumes` and edit the `USER` and `SERVER`.
   When you finish that save the file.
   
   Now we are going to edit a new file, `httpd.conf`:
   ```bash
   nano httpd.conf
   ```
   In this file assuming you just want to do a reverse proxy like me you will want to ignore everything and go to line 130:
   ```conf
	<Location "/" >
		ProxyPreserveHost On
		ProxyPass http://wasp-webapp:3000/
		ProxyPassReverse http://wasp-webapp:3000/
	</Location>

	<Location "/hooks" >
		ProxyPreserveHost On
		ProxyPass http://wasp-discord:4000/
		ProxyPassReverse http://wasp-discord:4000/
	</Location>
   ```
   Here you are going to set `Location "/"` to the location you want your app on.
   For example if you want waspscripts.com/app1 you would change it to `Location "/app1".
   I want my root url to be one of my wasp-webapp so I have it as `Location "/"`.
   
   I also have another app, my discord bot that listens to webhooks and I want it to live in waspscripts.com/hooks so it's `Location "/hooks`.
   
   I hope that makes sense.
   
   Then on `ProxyPass`and `ProxyPassReverse` you need to add the docker container they are living on and on which port.
   I'll cover an example soon of this but setting this up is not part of this tutorial.
   You can also add more locations if you want for whatever you want.
   When you are done save and close the file.
  
  ### Run The Server
   You can run your server with:
   ```bash
   sudo docker-compose up -d
   ```
   And if you ever want to stop it, you can navigate to the directory and use:
   ```bash
   sudo docker-compose down
   ```
   You can verify your server is running by using the following command:
   ```bash
   sudo docker container ls
   ```
   And it will show you all running containers.
   
 ## Running Apps
  Your app will need a Dockerfile or you need to edit the following example to handle it.
  Assuming you have a Dockerfile you will want to have a `docker-compose.yml` in the root of your app similar to this:
  ```yml
  version: "3.9"

  services:
    wasp-webapp:
      container_name: "wasp-webapp"
      build:
        context: .
      restart: unless-stopped
      networks:
        - wasp-server_proxy

  networks:
    wasp-server_proxy:
      external: true
  ```
  The things you need to note from here is that `wasp-webapp` in both places should match what you put in your `ProxyPass` and `ProxyPassReverse`.
  And `wasp-server_proxy` should match the network your server is running on.
  You can check which network it's running on with this command:
  ```bash
  sudo docker network ls
  ```
  And if you did everything correctly when you visit the URL of you app you should see it:
  ![Live app](https://raw.githubusercontent.com/Torwent/wasp-server/master/docs/setup.png)