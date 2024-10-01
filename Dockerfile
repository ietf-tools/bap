ARG CENTOS_VERSION="7.9.2009"

# For remote
# ARG BAP_GIT_URL="https://github.com/ietf-tools/bap.git"

FROM --platform=linux/amd64 centos:${CENTOS_VERSION} as base
ARG CENTOS_VERSION
ENV CENTOS_VERSION=${CENTOS_VERSION}
RUN \
    sed -i \
    	'/^mirrorlist/d' \
	/etc/yum.repos.d/CentOS-Base.repo \
    && \
    sed -i \
    	's/^#baseurl=http:\/\/mirror\.centos\.org\/centos/baseurl=http:\/\/archive\.kernel\.org\/centos-vault/g' \
	/etc/yum.repos.d/CentOS-Base.repo \
    && \
    sed -i \
    	"s/\$releasever/${CENTOS_VERSION}/g" \
	/etc/yum.repos.d/CentOS-Base.repo \
    && \
    groupadd -g 1000 centos \
    && \
    useradd -g 1000 -u 1000 centos

FROM base AS build

# For remote
# ARG BAP_GIT_URL
# ENV BAP_GIT_URL=${BAP_GIT_URL}

RUN yum -y install \
    	gcc-c++ \
	byacc \
	bison \
	bison-devel \
	flex \
	flex-devel \
	make \
	git
USER centos
WORKDIR /home/centos

# For remote
# RUN git clone ${BAP_GIT_URL}

# Comment out next line if using remote
COPY --chown=centos:centos . /home/centos/bap
WORKDIR /home/centos/bap
RUN ./configure && make

FROM base AS production
WORKDIR /home/centos/
USER centos
COPY --from=build /home/centos/bap/bap /home/centos/bap
ENTRYPOINT ["/home/centos/bap"]
