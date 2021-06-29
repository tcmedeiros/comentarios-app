ARG REPO

FROM $REPO/python:3

WORKDIR /usr/src/app

RUN pip install Flask
RUN pip install gunicorn

COPY app/* ./

CMD gunicorn -b 0.0.0.0 --log-level debug api:app

EXPOSE 8000