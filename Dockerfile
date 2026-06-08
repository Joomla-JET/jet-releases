FROM joomla

ARG WWWUSER=1000
ARG WWWGROUP=1000

RUN groupmod -o -g ${WWWGROUP} www-data \
    && usermod -o -u ${WWWUSER} -g www-data www-data