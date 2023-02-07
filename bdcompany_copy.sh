#! /bin/bash
#nos ubicamos en directorio de nuestro usuario
cd ~

#verificamos si existe directorio de respaldos (backups)
directorio=/var/backups/mongobackups
#echo $directorio
if [ -d "$directorio" ]
then
	echo "El directorio existe"
else
	#creamos directorio de respaldos
	echo "El directorio NO existe"
	sudo mkdir /var/backups/mongobackups

	#y hacemos mongodump a nuestro path
	sudo mongodump --db w4m --out /var/backups/mongobackups
	echo "Backup finalizado y almacenado en $directorio"
fi

#almacenamos parametro con nombre de BD
dbname=$2'w4m'
#echo "El nombre de la BD es: $dbname"
sudo mongorestore --db $dbname /var/backups/mongobackups/w4m
echo "BD $dbname RESTABLECIDA de $directorio/w4m"

# Set variables
new_port=$1
new_company=$2

# Copy Web service
rsync -av --progress ~/whealth4me-back-end/api ~/${new_company} --exclude api/node_modules --exclude api/client/node_modules

# Replace PORT
sed -i "s/3002/${new_port}/" ~/${new_company}/api/package.json

# Replace DB_NAME
sed -i "s@mongodb://localhost:27017/w4m@mongodb://localhost:27017/${new_company}w4m@" ~/${new_company}/api/lib/config.js

#Replace url API
#Remplazar por IP de servidor de producción
sed -i "s@http://3.141.100.124:3002/@http://192.168.1.4:${new_port}/@" ~/${new_company}/api/client/app/app.config.ts

sed -i "s@http://3.141.100.124:3002/@http://192.168.1.4:${new_port}/@g" ~/${new_company}/api/client/dist/app.bundle.js

sed -i "s@localhost@192.168.1.4@g" ~/${new_company}/api/client/dist/app.bundle.js

# Append config info to companies doc
echo "COMPANY=${new_company}, PORT=${new_port}, DB_NAME=${new_company}w4m" >> ~/companies.txt

# Install packages
cd ~/${new_company}/api
npm i

# Start service
pm2 start "npm run start"
cd ~
