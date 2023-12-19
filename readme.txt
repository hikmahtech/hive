docker build \
        -f Dockerfile \
        -t arshadansari27/hive:4.0.0-beta-1 \
        --build-arg "HIVE_VERSION=4.0.0-beta-1" \
        --build-arg "HADOOP_VERSION=3.3.1" \
        --build-arg "TEZ_VERSION=0.10.2" .
        
