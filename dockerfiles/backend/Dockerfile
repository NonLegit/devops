FROM node:latest

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install && npm ci --only=production

COPY . .

RUN chmod +x script-up.sh

RUN chown -R node:node /home/node

EXPOSE 8000

USER node

CMD ["./script-up.sh"]
