#!/bin/bash
set -Eeuo pipefail
export DOCKER_TAG="2019-CU8-ubuntu-16.04"
IMAGES=(
	mssql-app-service-proxy
        mssql-control-watchdog
        mssql-controller
        mssql-dns
        mssql-hadoop
        mssql-mleap-serving-runtime
        mssql-mlserver-py-runtime
        mssql-mlserver-r-runtime
        mssql-monitor-collectd
        mssql-monitor-elasticsearch
        mssql-monitor-fluentbit
        mssql-monitor-grafana
        mssql-monitor-influxdb
        mssql-monitor-kibana
        mssql-monitor-telegraf
        mssql-security-knox
        mssql-security-support
        mssql-server-controller
        mssql-server-data
        mssql-ha-operator
		mssql-ha-supervisor
        mssql-service-proxy
        mssql-ssis-app-runtime
)

for image in "${IMAGES[@]}";
do
    docker pull mcr.microsoft.com/mssql/bdc/$image:$DOCKER_TAG
    echo "Docker image" $image " pulled."
done
echo "Docker images pulled." 
