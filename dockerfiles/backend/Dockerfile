FROM node:latest

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install && npm ci --only=production

COPY . .

RUN chmod +x script-up.sh

EXPOSE 443

CMD ["./script-up.sh"]
