FROM python:3.13-alpine

WORKDIR /usr/src/app
RUN mkdir output

ADD requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
ADD *.py ./

CMD ["echo", "Please refer to README for use of available scripts in this container."]
