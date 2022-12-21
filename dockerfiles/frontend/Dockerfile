FROM node:16.17.0 

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm install --force --omit=dev 

# EDIT the /usr/src/app/node_modules/node_modules/react-scripts/config
RUN sed -i '306 i fallback: { crypto: false },' /usr/src/app/node_modules/react-scripts/config/webpack.config.js

COPY . .

EXPOSE 443

CMD [ "npm", "start" ]
