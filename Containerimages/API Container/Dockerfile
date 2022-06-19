FROM node:16

RUN apt update 

RUN apt install curl unzip -y

RUN curl -L -O https://github.com/eliagarzi/zuericloudmonitoring/archive/refs/heads/main.zip

RUN unzip main.zip

RUN cp /zuericloudmonitoring/api/. /app/

RUN rm /zuericloudmonitoring/

WORKDIR /app/

COPY package*.json ./

RUN npm install

COPY . .

ENV PORT=8080

EXPOSE 8080

CMD [ "npm", "start"]