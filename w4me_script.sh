#! /bin/bash
# sudo sh bdcompany_copy.sh <SERVICE_PORT> <COMPANY_NAME> <SOCKET_PORT> <IP_SERVER>

# Port for service
new_port=$1
# Company name
new_company=$2
# Port for socket
new_port_socket=$3
# IP Server
ip_server=$(hostname -I | xargs)
# Db name for company
db_name=$2'w4m'

# Base project repository
repo='git@labgit.linkthinks.com:Daniel/w4me_devops_resources.git'
dir_base_project=/w4m_devops_resources

# Handle errors
on_error(){
    echo "Error found in: $(caller)" >&2 >> ~/w4m-logs/${new_company}-$(date).txt
}
trap 'on_error' ERR

# Locate in Home dir
cd ~

# Verify for base project dir
if [ ! -d "$dir_base_project" ]
then
    # Clone project
	echo "Cloning repository"
	git clone ${repo}

    [ ! -d "$dir_base_project" ] && { echo "ERROR: Failed to clone repository" && exit 1 }
fi

# Update base project dir
echo "Checking for updates from the repository"
git pull ${repo} main

# MONGORESTORE COMMAND HELP
# Restore mongodb databse from backup dir or file
# mongorestore --db <destination_db> <directory_or_file_to_restore>
# -db - specifies the destination database for mongorestore

# Restore db
sudo mongorestore --db $db_name ~/${dir_base_project}/w4m/w4m

# Query if DB exists in MongoDB
mongo_indexof_db=$(mongo --quiet --eval 'db.getMongo().getDBNames().indexOf("${db_name}")')
if [ $mongo_indexof_db -ne "-1" ]; then
    echo "DB $db_name RESTORED from $dir_backup/w4m"
else
    echo "ERROR: Failed to restore database"
    exit 1
fi

# Copy Project
rsync -av --progress ~/whealth4me-back-end/api ~/${new_company} --exclude api/node_modules --exclude api/client/node_modules

# SED COMMAND HELP
# Stream editor to edit files quickly and efficiently
# sed -i "s/<original_text>/<new_text>/g" <file_path>
# <s> - substitute: find and replace string
# <g> - replace all ocurrences for each line in the file
# -i  - creates a temporary file that replaces the source file
# </> - works as delimiter (it can be substitute for other character Ex."@")

# Replace service PORT
sed -i "s/3002/${new_port}/" ~/${new_company}/api/package.json

# Replace DB_NAME
sed -i "s@mongodb://localhost:27017/w4m@mongodb://localhost:27017/${db_name}@" ~/${new_company}/api/lib/config.js

#Replace API url
sed -i "s@http://3.141.100.124:3002/@http://${ip_server}:${new_port}/@" ~/${new_company}/api/client/app/app.config.ts
sed -i "s@http://3.141.100.124:3002/@http://${ip_server}:${new_port}/@g" ~/${new_company}/api/client/dist/app.bundle.js
sed -i "s@localhost:8081@${ip_server}:${new_port_socket}@g" ~/${new_company}/api/client/dist/vendor.bundle.js

# Remove livereload for production
sed -i "s@var livereload = require('livereload');@//var livereload = require('livereload');@g" ~/${new_company}/api/bin/www
sed -i "s@  var lrserver = livereload.createServer();@//var lrserver = livereload.createServer();@g" ~/${new_company}/api/bin/www
sed -i "s@lrserver.watch@//lrserver.watch@g" ~/${new_company}/api/bin/www

# Append config info into companies doc file
echo "COMPANY=${new_company}, PORT=${new_port}, DB_NAME=${db_name}, PORT_SOCKET=${new_port_socket}" >> ~/companies.txt

# Install packages
cd ~/${new_company}/api
sed -i "s/&& npm start/ /" ~/${new_company}/api/package.json
npm i --legacy-peer-deps

# Remove livereload
echo "Removing livereload..."
npm remove livereload

# PM2 COMMAND HELP
# Daemonize and monitor node application
# pm2 start <service> --name <service_alias>
# --name - set an alias for running service

# Start service
pm2 start "npm run start" --name ${new_company}
echo "FINISHED pm2 start 'npm run start' --name ${new_company}"
pm2 save
echo "FINISHED pm2 save"
