FROM registry.fedoraproject.org/fedora
COPY . /src/
RUN mkdir /testrun
RUN cp -r /src/t /testrun/t
RUN cd /src && ci/build.sh
WORKDIR /testrun
