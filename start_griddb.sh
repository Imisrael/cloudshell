#!/bin/bash

chown gsadm.gridstore /var/lib/gridstore/data

IP=`grep $HOSTNAME /etc/hosts | awk ' { print $1 }'`

cat << EOF > /var/lib/gridstore/conf/gs_cluster.json
{
        "dataStore":{
                "partitionNum":128,
                "storeBlockSize":"64KB"
        },
        "cluster":{
                "clusterName":"defaultCluster",
                "replicationNum":2,
                "notificationInterval":"5s",
                "heartbeatInterval":"5s",
                "loadbalanceCheckInterval":"180s",
                "notificationMember": [
                        {
                                "cluster": {"address":"$IP", "port":10010},
                                "sync": {"address":"$IP", "port":10020},
                                "system": {"address":"$IP", "port":10040},
                                "transaction": {"address":"$IP", "port":10001},
                                "sql": {"address":"$IP", "port":20001}
                       }
                ]
        },
        "sync":{
                "timeoutInterval":"30s"
        },
	    "transaction":{
		    "notificationAddress":"239.0.0.1",
		    "notificationPort":31999,
		    "notificationInterval":"5s",
		    "replicationMode":0,
		    "replicationTimeoutInterval":"10s"
	    },
	    "sql":{
		    "notificationAddress":"239.0.0.1",
		    "notificationPort":41999,
		    "notificationInterval":"5s"
	    }
    }
EOF

cat << EOF > /var/lib/gridstore/conf/gs_node.json
{
    "dataStore":{
        "dbPath":"data",
        "backupPath":"backup",
        "syncTempPath":"sync",
        "storeMemoryLimit":"1024MB",
        "storeWarmStart":false,
        "storeCompressionMode":"NO_COMPRESSION",
        "concurrency":4,
        "logWriteMode":1,
        "persistencyMode":"NORMAL",
        "affinityGroupSize":4,
        "autoExpire":false
    },
    "checkpoint":{
        "checkpointInterval":"60s",
        "checkpointMemoryLimit":"1024MB",
        "useParallelMode":false
    },
    "cluster":{
        "servicePort":10010
    },
    "sync":{
        "servicePort":10020
    },
    "system":{
        "servicePort":10040,
        "eventLogPath":"log"
    },
    "transaction":{
        "servicePort":10001,
        "connectionLimit":5000
    },
	"sql":{
		"servicePort":20001,
		"storeSwapFilePath":"swap",
		"storeSwapSyncSize":"1024MB",
		"storeMemoryLimit":"1024MB",
		"workMemoryLimit":"32MB",
		"workCacheMemory":"128MB",
		"connectionLimit":5000,
		"concurrency":4
	},
    "trace":{
        "default":"LEVEL_ERROR",
        "dataStore":"LEVEL_ERROR",
        "collection":"LEVEL_ERROR",
        "timeSeries":"LEVEL_ERROR",
        "chunkManager":"LEVEL_ERROR",
        "objectManager":"LEVEL_ERROR",
        "checkpointFile":"LEVEL_ERROR",
        "checkpointService":"LEVEL_INFO",
        "logManager":"LEVEL_WARNING",
        "clusterService":"LEVEL_ERROR",
        "syncService":"LEVEL_ERROR",
        "systemService":"LEVEL_INFO",
        "transactionManager":"LEVEL_ERROR",
        "transactionService":"LEVEL_ERROR",
        "transactionTimeout":"LEVEL_WARNING",
        "triggerService":"LEVEL_ERROR",
        "sessionTimeout":"LEVEL_WARNING",
        "replicationTimeout":"LEVEL_WARNING",
        "recoveryManager":"LEVEL_INFO",
        "eventEngine":"LEVEL_WARNING",
        "clusterOperation":"LEVEL_INFO",
        "ioMonitor":"LEVEL_WARNING"
    }
}
EOF

/usr/bin/gs_passwd admin -p admin
/usr/bin/gs_startnode

echo Going to start up the waiting loop?
sleep 10

while /usr/bin/gs_stat -u admin/admin | grep RECOV > /dev/null; do
    echo Waiting for GridDB to be ready.
    sleep 5
done

/usr/bin/gs_joincluster -u admin/admin

tail -f /var/lib/gridstore/log/gridstore*.log

/usr/bin/gs_sh
#setuser admin admin
#sync 127.0.0.1 10040 defaultCluster node0
