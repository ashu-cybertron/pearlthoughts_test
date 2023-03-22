FROM node:latest

WORKDIR /app

COPY package*.json ./

RUN npm install

RUN npm install express

RUN mkdir /home/runner/work/pearlthoughts_test/pearlthoughts_test/
COPY ./* /home/runner/work/pearlthoughts_test/pearlthoughts_test/
COPY ./* ./

EXPOSE 3000

CMD ["node", "server.js"]