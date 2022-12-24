#!/bin/bash -xe

cd ~
# Installing apache and cerbot..
yum update -y
yum install yum-utils bash-completion jq vim -y 
yum install httpd -y

rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-9
yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -y
yum install libaugeas.so.0 augeas -y

# Installing docker..
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
rpm --import https://download.docker.com/linux/centos/gpg
yum install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
pip3 install certbot certbot-apache certbot-dns-route53

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf ./aws*

systemctl enable --now docker.service
usermod -a -G docker ec2-user

mkdir workspace && cd workspace

# Setting github credentials...
export GITHUB_PASSWORD=`aws secretsmanager get-secret-value --region us-east-1 --secret-id github-credentials | jq '.SecretString' | cut -d\" -f 2`
echo -e '#!/bin/bash\nexec echo $GITHUB_PASSWORD'  > git_askpass_helper.sh
chmod +x git_askpass_helper.sh
export GIT_ASKPASS=`readlink -f git_askpass_helper.sh`

# Pulling repositories..
git clone https://cynico@github.com/NonLegit/devops.git

# Configuring apache..
APACHE_BASE=/etc/httpd

rm -f $APACHE_BASE/conf.d/{welcome.conf,userdir.conf,README}
mkdir $APACHE_BASE/sites

cp -v devops/configuration-management/apache/* $APACHE_BASE/sites/
sed -i "s/nonlegit.click/horizontverschmelzung.click/g" $APACHE_BASE/sites/*


ln -s $APACHE_BASE/sites/web.nonlegit.click-le-ssl.conf $APACHE_BASE/conf.d/00-web.conf
ln -s $APACHE_BASE/sites/api.nonlegit.click-le-ssl.conf $APACHE_BASE/conf.d/01-api.conf
ln -s $APACHE_BASE/sites/app.nonlegit.click-le-ssl.conf $APACHE_BASE/conf.d/03-app.conf

# Obtaining our certificates..
certbot -d '*.horizontverschmelzung.click' --dns-route53 --installer apache --agree-tos -m ysi.rabie@gmail.com -n --dns-route53

# Placing the certificates
for vhost in 00-web 01-api 03-app
do
    sed -i 's/#REPLACE_CERTS_PATH/SSLCertificateFile \/etc\/letsencrypt\/live\/horizontverschmelzung.click\/fullchain.pem\nSSLCertificateKeyFile \/etc\/letsencrypt\/live\/horizontverschmelzung.click\/privkey.pem\nInclude \/etc\/letsencrypt\/options-ssl-apache.conf/g' $APACHE_BASE/conf.d/$vhost.conf
    sed -i 's/#REPLACE_IF/<IfModule mod_ssl.c>/g' $APACHE_BASE/conf.d/$vhost.conf
    sed -i 's/#REPLACE_END_OF_IF/<\/IfModule>/g' $APACHE_BASE/conf.d/$vhost.conf

done
sed -i 's/80/443/g' $APACHE_BASE/conf.d/03-app.conf


yum install mod_ssl -y
setsebool -P httpd_can_network_connect 1
systemctl enable --now httpd.service

##  Building backend
docker pull cynic0/reddit-backend:latest
docker pull mongo:latest

# Getting the database credentials.
DB_CREDS=`aws secretsmanager get-secret-value --region us-east-1 --secret-id db-credentials | jq '.SecretString'`
DB_CREDS="${DB_CREDS:1:${#DB_CREDS}-2}"
echo $DB_CREDS > temp-db
DB_CREDS=$(sed 's/\\"/"/g' temp-db)
rm -f temp-db

export DB_USER=$(echo $DB_CREDS | jq '.DB_USERNAME' | cut -d\" -f2)
export DB_PASSWORD=$(echo $DB_CREDS | jq '.DB_PASSWORD' | cut -d\" -f2)
unset DB_CREDS

# Overwriting the necessary in .env file.
docker run --rm -v $PWD:/bind cynic0/reddit-backend:latest cp /usr/src/app/.env /bind
sed -i 's/api.nonlegit/api.horizontverchmelzung/g;s/web.nonlegit/web.horizontverchmelzung/g;s/app.nonlegit/app.horizontverchmelzung/g;' .env
sed -E -i "s/^DATABASE=.*$/DATABASE=mongodb:\/\/$DB_USER:$DB_PASSWORD@mongodb\/redditDB?authSource=admin/g" .env

echo "FROM cynic0/reddit-backend:latest
COPY ./.env /usr/src/app 
" > Dockerfile
docker build -t cynic0/reddit-backend:latest .
rm -f .env Dockerfile

mkdir backend && cd backend
cp ../devops/dockerfiles/backend/docker-compose.yaml .
sed -i "s/DB_USER/$DB_USER/g;s/DB_PASSWORD/$DB_PASSWORD/g" docker-compose.yaml
unset DB_USER DB_PASSWORD

# Fetching static assets into EFS..
git init temp && cd temp
git remote add -f origin https://github.com/NonLegit/Backend-Reddit.git
git config core.sparseCheckout true
echo "API/public" >> .git/info/sparse-checkout
git pull origin main
rm -rf /var/bind/public/*
mv API/public/* /var/bind/public
cd .. && rm -rf temp

docker compose up -d

# Deploying frontend..
mkdir ../frontend && cd ../frontend
docker pull cynic0/reddit-frontend:latest

# Overwriting the necessary in .env file.
docker run --rm -v $PWD:/bind cynic0/reddit-frontend:latest cp /usr/src/app/.env /bind
sed -i 's/nonlegit/horizontverschmelzung/g;' .env

echo "FROM cynic0/reddit-frontend:latest
COPY ./.env /usr/src/app 
" > Dockerfile
docker build -t cynic0/reddit-frontend:latest .
rm -f .env Dockerfile

docker run --name=frontend --network backend_backend --ip 10.0.1.4 --restart always -d cynic0/reddit-frontend:latest

# Deploying flutter..
mkdir ../cross && cd ../cross
docker pull cynic0/flutter-image:latest
docker pull cynic0/reddit-flutter:latest

docker run -d --name=flutter --network backend_backend --ip 10.0.1.5 --restart always cynic0/reddit-flutter:latest
